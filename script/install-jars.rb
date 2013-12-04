#!/usr/bin/env ruby

# Extremely primitive JRuby dependency handler for JARs we can't redistribute publicly:
# 1. Check for the JAR libraries we expect to be in place.
# 2. If they're not installed yet, try to download from MAVEN_REPO to the JRuby's main "lib" directory.
# The MAVEN_REPO environment variable must point to a private repository.
# This confluence page has docs on keeping MAVEN_REPO updated: https://confluence.media.berkeley.edu/confluence/x/64EYAQ

abort "ERROR: No MAVEN_REPO is defined" unless ENV['MAVEN_REPO']

def knows_class?(classname)
  begin
    eval("Java::#{classname}.class")
    true
  rescue NameError
    false
  end
end

if knows_class?("SunJvmstatMonitor::MonitoredHost")
  puts "JDK tools.jar is already installed"
else
  puts "No JDK tools.jar; will try to install it from #{ENV['MAVEN_REPO']}"
  puts "  to #{ENV['MY_RUBY_HOME']}/lib"
  `wget "#{ENV['MAVEN_REPO']}/com/oracle/openjdk/tools/1.6.0.0.x86_64/tools-1.6.0.0.x86_64.jar" -P "#{ENV['MY_RUBY_HOME']}/lib"`
end

puts "Installing Oracle jar from #{ENV['MAVEN_REPO']}"
puts "  to #{ENV['MY_RUBY_HOME']}/lib"
`wget "#{ENV['MAVEN_REPO']}/com/oracle/ojdbc7/12.1.0.1/ojdbc7-12.1.0.1.jar" -P "#{ENV['MY_RUBY_HOME']}/lib"`
puts "Copying Oracle jar into ./lib"
`cp -f "#{ENV['MY_RUBY_HOME']}/lib/ojdbc7-12.1.0.1.jar" "#{File.expand_path(File.dirname(__FILE__))}/../lib/"`
