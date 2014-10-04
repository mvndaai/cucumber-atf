require_relative "dillify/version"

END{
  check_arguments
  read_verify_output_file
  parse_file
}

def check_arguments
  help if ARGV.any? && (ARGV[0] == '-h' || ARGV[0] == '--help')
  version if ARGV.any? && (ARGV[0] == '-v' || ARGV[0] == '--version')
  if !ARGV.any? || !File.file?(ARGV[0])
    puts "Please give a cucumber --out file as an argument"
    exit
  end
end

def version
  puts "dillify - #{Dillify::VERSION}"
  exit
end

def help
  puts 'usage: dillify <cucumber out file>'
  exit
end

def read_verify_output_file
  @output = File.open(ARGV[0], 'r') {|f| f.read }
  if !(@output.include? 'Failing')
    puts "File does not contain the word 'Failing'"
    exit
  end
end

def parse_file
  error_hash = gather_erring_steps
  display_errors_by_amount(error_hash)
end

def gather_erring_steps
  errors = Hash.new
  file = File.open(ARGV[0], 'r') {|f| f.read }
  file.each_line do |line|
    if line.include?('./features') && line.include?('in `/^')
      step = line.split('/^')[1].split('$/')[0]
      if errors[step].nil?
        errors[step] = 1
      else
        errors[step] = errors[step] + 1
      end
    end
  end
  errors
end

def display_errors_by_amount(hash)
  hash = hash.sort_by {|_k,v| v}
  hash.reverse!

  @total = 0
  puts '| Failures | Step'
  puts '-------------------'
  hash.each do |k,v|
    puts "| #{v.to_s.rjust(6)}   | #{k}"
    @total += v
  end
  puts '-------------------'
  puts "Total Failures: #{@total}"
end
