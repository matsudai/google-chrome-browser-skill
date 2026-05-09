require 'drb/drb'
require 'drb/unix'
require 'fileutils'
require 'stringio'
require 'ferrum'

session = ARGV[0]&.sub(/\A--session=/, '') or abort 'need --session=<id>'

base = File.expand_path('~/.claude/cache-browser-user-data-dirs')
FileUtils.mkdir_p(base)

# 起動時掃除: rb_pid または claude_pid が死んでる過去インスタンスを回収
Dir.glob("#{base}/instance-rb*-cl*").each do |dir|
  m = File.basename(dir).match(/\Ainstance-rb(\d+)-cl(\d+)\z/) or next
  rb_alive = (Process.kill(0, m[1].to_i) rescue false)
  cl_alive = (Process.kill(0, m[2].to_i) rescue false)
  FileUtils.rm_rf(dir) unless rb_alive && cl_alive
end

ruby_pid = Process.pid
claude_pid = `ps -o ppid= -p #{Process.ppid}`.strip.to_i

work = "#{base}/instance-rb#{ruby_pid}-cl#{claude_pid}"
chrome_dir = "#{work}/chrome"
FileUtils.mkdir_p(chrome_dir)
sock = "#{work}/sock"

browser = Ferrum::Browser.new(headless: 'new', browser_options: { 'user-data-dir' => chrome_dir })
chrome_pid = browser.process.pid

TOPLEVEL_BINDING.local_variable_set(:browser, browser)

cleanup = lambda do
  browser.quit rescue nil
  FileUtils.rm_rf(work)
  # 全instance消えていれば base 自体rm (server.rb/client.rb はskill同梱なので無関係、純粋にinstance群とbase空dirの掃除)
  FileUtils.rm_rf(base) if Dir.glob("#{base}/instance-*").empty?
end

Signal.trap('TERM') { cleanup.call; exit!(0) }
at_exit { cleanup.call }

# Chrome死亡監視
Thread.new { Process.wait2(chrome_pid) rescue nil; cleanup.call; exit!(0) }

# Supervisor: claude_pid死亡監視
Thread.new do
  loop do
    sleep 60
    Process.kill(0, claude_pid) rescue (cleanup.call; exit!(0))
  end
end

class Evaluator
  def evaluate(code)
    out, err = StringIO.new, StringIO.new
    saved_out, saved_err = $stdout, $stderr
    $stdout, $stderr = out, err
    begin
      r = TOPLEVEL_BINDING.eval(code)
      { result: r.inspect, stdout: out.string, stderr: err.string, error: nil }
    rescue Exception => e
      { result: nil, stdout: out.string, stderr: err.string,
        error: "#{e.class}: #{e.message}", backtrace: (e.backtrace || []).first(5) }
    ensure
      $stdout, $stderr = saved_out, saved_err
    end
  end
end

DRb.start_service("drbunix:#{sock}", Evaluator.new)
puts "ready: sock=#{sock} pid=#{ruby_pid} chrome_pid=#{chrome_pid}"
$stdout.flush
DRb.thread.join
