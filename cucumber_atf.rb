# -------------------------------------------------------------
# Cucumber Automation Test Framework
# Created by Jason Mavandi
# mvndaai@gmail.com
# Created Feb 7, 2013
# Verion 0.1.0 
#
# Currently only works on Mac (maybe Linux)
# * Will not work on Windows
#
# Current Features
# - Choose a bus-web-auto-test from your computer
# - Find all tags with @TC. excluding any tag you want
# - List amount of tests to be run
# - Run test cases from list of tags above
# - Verify if test cases passed or failed
# - Creates log file based on bus/phx versions 
# - Create report of all passed/failed cases
#
#
# Wanted Features
# - Find all test cases missing important tags
# - Work on windows
#
# -------------------------------------------------------------

# Required Variables
@cucumber_folder_name            #Takes a string
@important_tags                  #Takes an array
@log_folder_name = 'Cucumber_ATF'
# Optional variables
@unimportant_tags = ['#']        #Takes an array 
@run_option                      #Takes a character, listed below 
                  #(n)ormal, (c)lean, (r)etry non passed, (s)kip failed, run (f)ailed

END {
verify_required_inputs
@directory =  ask_which_directory(get_cucumber_directories)
run_test_cases(@directory,get_tags)
print "\n\n"
} 

#Setup
def get_cucumber_directories
  instances = []
  #NOTE: change maxdepth if you want to check your computer deeper
  folders = `cd ~/; find . 2>/dev/null -maxdepth 6 -type d | grep #{@cucumber_folder_name}`
  folders.each_line do |line|
    instances << line.chomp if line.include? "#{@cucumber_folder_name}\n" unless line.include? 'Trash'
  end
  instances 
end
def ask_which_directory(directory_array)
  #This is how to choose with cucumber project if there are multipule on your computer
  # If this file is within the cucumber project it will choose this
  # If it cannot find a project on your computer it will tell you to download
  # If there is only one installation on the computer it will choose that
  # If there are multiple installations it will list them for you
  return `pwd`.slice(0..(str.index(@cucumber_folder_name)))if `pwd`.include? @cucumber_folder_name
  
  if directory_array.length == 0
puts 'Please download the project'
    abort
  elsif directory_array.length == 1
    return directory_array[0]
  else
    puts "\nChoose cucumber installation(#{@cucumber_folder_name})"
    return ask_from_array(directory_array)
  end
end
def verify_required_inputs
  required_vars = [@cucumber_folder_name,@log_folder_name,@important_tags]
  required_vars.each {|item| puts "Please fill in required items" if item.nil?}
end

def get_tags(run_option=nil)
  @run_option ||= 'n'
  run_option = @run_option if run_option.nil?

  case(run_option)
  when 'n' #(n)ormal
    normal = get_non_passed_tags
    return normal if normal.any?
    get_all_tags(@directory)
  when 'c' #(c)lean 
    get_all_tags(@directory)
  when 'r' #(r)etry non passed 
    get_non_passed_tags
  when 's' #(s)kip failed
    get_all_tags(@directory) - get_failed_tags
  when 'f' #run (f)ailed
    get_failed_tags
  end
end
def get_all_tags(directory)
  files = `cd #{directory}; find . 2>/dev/null -maxdepth 7| grep -F "\.feature"`
  tag_lines = ''
  files.each_line do |file|
    tag_lines += `grep '@TC' #{directory}#{file[1..-1]}`
  end
  tag_array = [] 
  tag_lines.each_line do |line|
    unless includes_any(line,@unimportant_tags)
      line.split(' ').each{|item| tag_array << item if includes_any(item,@important_tags)}
    end
  end
  tag_array
end
def get_failed_tags
  cleanup_summary
  if File.exists? File.join(log_folder_path,log_filename('summary'))
    failed,passed = [],[]
    summary = read_file(log_folder_path,log_filename('summary'))
    summary.each_line do |line|
      if line.include? 'Failed:'
        line = line.strip.gsub(' ','').gsub('"','').gsub('Failed:','').gsub('[','').gsub(']','').split(',')
        line.each do |tag|
          failed << tag
        end
      end
      if line.include? 'Passed:'
        line = line.strip.gsub(' ','').gsub('"','').gsub('Passed:','').gsub('[','').gsub(']','').split(',')
        line.each do |tag|
          passed << tag
        end
      end
    end
  end
  failed = failed.uniq - passed.uniq
  failed
end
def get_non_passed_tags
  cleanup_summary
  if File.exists? File.join(log_folder_path,log_filename('summary'))
    all,passed = [],[]
    summary = read_file(log_folder_path,log_filename('summary'))
    summary.each_line do |line|
      if line.include? 'All:'
        line = line.strip.gsub(' ','').gsub('"','').gsub('[','').gsub(']','').split(',').gsub('All:','')
        line.each do |tag|
          all << tag
        end
      end
      if line.include? 'Passed:'
        line = line.strip.gsub(' ','').gsub('"','').gsub('[','').gsub(']','').split(',').gsub('Passed:','')
        line.each do |tag|
          passed << tag
        end
      end
    end
  end
  all = all.uniq - passed.uniq
  all
end

#Running
def run_test_cases(directory,array)
  puts "Test cases to run: #{array.length}"
  log_start(array)
  
  passed,failed = [],[]
  array.each.with_index do |tag,index|
    cmd  = "cd #{directory}; bundle exec cucumber -t #{tag}"
    puts "Running test case #{tag} (#{index+1} of #{array.length})"
    report = `#{cmd}`
    
    result = cucumber_passed?(report)
    puts "Test case #{result ? 'passed' : 'failed'}\n"
    log_result(tag,result)
    
    if result
      passed << tag 
    else
      failed << tag
      log_failure(report)
    end
  end
  print "Passed: #{passed}\n"
  print "Failed: #{failed}\n"
end
def cucumber_passed?(string)
  (string.include? 'Failing Scenarios') ? false : true
end

## Log stuff
def log_folder_path
  `cd #{@directory}; mkdir log` unless `cd #{@directory}; ls`.include? 'log'
  log_folder = File.join(@directory,'log')
  `cd #{log_folder}; mkdir #{@log_folder_name}` unless `cd #{log_folder}; ls`.include? @log_folder_name  
  File.join(@directory,'log',@log_folder_name)
end
def log_filename(string)
  if instance_variable_get("@#{string}").nil?
    instance_variable_set("@#{string}", "#{string}.log") 
  end
  instance_variable_get("@#{string}")
end
def log_start(tags)
  string = "Recent (#{time})\nAll:#{tags}\n"
  if @run_option == 'c'
    if File.exists? File.join(log_folder_path,log_filename('summary'))
      old_log = read_file(log_folder_path,log_filename('summary'))
      filename = "#{log_filename('summary').gsub('.log','')}_before_#{time}.log"
      create_file(old_log,log_folder_path,filename)
      create_file(string,log_folder_path,log_filename('summary'))
      return
    end
  end
  append_to_file(string,log_folder_path,log_filename('summary'))    
end
def log_failure(report)
  weird = ['[0m','[1m','[31m','[32m','[36m','[90m']
  weird.each {|string| report = report.gsub(string,'')}
  string = "\n\n#{report}"
  append_to_file(string,log_folder_path,log_filename('failures'))    
end
def log_result(tag,result)
  string = result ? "#{tag}-Passed\n" : "#{tag}-Failed\n" 
  append_to_file(string,log_folder_path,log_filename('summary'))    
end
def cleanup_summary
  if File.exists? File.join(log_folder_path,log_filename('summary'))
    summary = read_file(log_folder_path,log_filename('summary'))
    if summary.include? 'Recent'
      summary = summary.gsub('Previous','Past')
      passed,failed,progress,recent = [],[],'',false
      summary.each_line do |line|
        progress += line if line.include? 'All:'
        passed << line.split('-')[0] if line.include? '-Passed' if recent
        failed << line.split('-')[0] if line.include? '-Failed' if recent
        if line.include? 'Recent'
          progress += line.gsub('Recent','Previous')
          recent = true
        end        
        progress += line unless recent
      end
      progress += "Passed:#{passed}\n"
      progress += "Failed:#{failed}\n\n"
      create_file(progress,log_folder_path,log_filename('summary'))
    end
  end
end

#Interact with Files
def append_to_file(string,filepath,filename)
  File.open(File.join(filepath,filename), 'a') {|f| f.write(string) }
end
def create_file(string,filepath,filename)
  File.open(File.join(filepath,filename), 'w') {|f| f.write(string) }
end
def read_file(filepath,filename)
  path = File.join(filepath,filename)
  `cat #{path}`
end

##### Asking Questions Helpers
def input_within(input,low,high)
  #puts "Input: #{input}\nLow: #{low}\nHigh: #{high}"
  return true if input >= low && input <= high
  false
end
def is_numeric?(obj) 
   obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
end
def ask_from_array(array)
  array.each.with_index do |item,index|
    puts "#{index+1}) #{item}"
  end
  
  while true
    selection = gets.chomp
    if is_numeric?(selection)
      return array[selection.to_i-1] if input_within(selection.to_i,1,array.length)
    elsif
      possibliities = Array.new
      array.each.with_index do |item,index|
        possibliities << index if item.downcase.include? selection.downcase.strip
      end
      return array[possibliities[0]] if possibliities.length == 1
    end
    puts "#{selection} is not a valid selection, try again:"
  end
end

#Other Helpers
def includes_any(string,include_array,exclude_array=nil)
  #TODO make faster by checking if exclude array exists once instead of each time
  include_array.each do |item|
    if string.include? item
      exclude_array.each { |excluded|  return false if string.include? excluded} if !!exclude_array
      return true
    end
  end 
  false
end
def combine_arrays(array_a,array_b)
  array_a << array_b
  array_a.flatten!
  array_a.uniq!
end
def time
  Time.now.to_s[0...-6].gsub(' ','_')
end
