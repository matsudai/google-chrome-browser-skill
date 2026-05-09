require 'drb/drb'
require 'drb/unix'

claude_pid = `ps -o ppid= -p #{Process.ppid}`.strip.to_i
base = File.expand_path('~/.claude/cache-browser-user-data-dirs')
sock = Dir.glob("#{base}/instance-rb*-cl#{claude_pid}/sock").find do |s|
  m = File.basename(File.dirname(s)).match(/\Ainstance-rb(\d+)-cl/)
  m && (Process.kill(0, m[1].to_i) rescue false)
end or abort "no live server for claude pid #{claude_pid}"

DRb.start_service
server = DRbObject.new_with_uri("drbunix:#{sock}")
code = ARGV[0] or abort 'usage: ruby client.rb "CODE"'
r = server.evaluate(code)

puts "[stdout] #{r[:stdout]}" unless r[:stdout].empty?
puts "[stderr] #{r[:stderr]}" unless r[:stderr].empty?
if r[:error]
  puts "[error]  #{r[:error]}"
  puts r[:backtrace]
else
  puts "=> #{r[:result]}"
end
