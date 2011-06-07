# runPDMS
#!/usr/bin/env ruby
#
require 'rubygems'
require 'sequel'
require 'yaml'

#~ # Configuration
def config()
	cfile = 'runPDMS.ini'
	if File.exists?(cfile)
		@cfg = YAML.load_file(cfile)
		# Settings
		@gui = @cfg['settings']['gui']
		@script = @cfg['settings']['script']
		@temp = @cfg['settings']['temp']
		@clean = @cfg['settings']['clean']
		@logo = @cfg['settings']['logo']
		type = @cfg['db']['type']
		db = @cfg['db']['file']
		#~ # Connect to DB
		conn = case type
			when 'sqlite' then "sqlite://#{db}"
			when 'mysql' then ""
		end
		if File.exists?(db)
			@db = Sequel.connect(conn)		
		else
			puts "Error with database (#{conn})."
			exit
		end
		@logf = @cfg['log']['file']
	else
		puts "Error loading file #{cfile}"
		exit
	end
end

def log(text)
	if @logf != ""
		File.open(@logf, "a+") do |log|
			ltext = "#{Time.now.localtime.to_s}; "
			ltext << "#{ENV['USERID']}; "
			ltext << "#{ENV['COMPUTERNAME']}; "
			ltext << "#{text}; "
			log.puts ltext
		end
	end
end

def isAdmin(user)
	users = @db[:user]
	@admin = false
	if users.filter(:login => user).first[:admin] == 1
		@admin = true
	end
end

def getProj(user)
	isAdmin(user)
	if @admin
		p = @db[:profile]
		profiles = @db[:user_profile]
		@projects = p.order(:name).all
		@last = profiles.filter(:user => user, :last => 1).first
	else
		profiles = @db[:user_profile]
		@projects = profiles.filter(:user => user).order(:profile).all
		@last = profiles.filter(:user => user, :last => 1).first
	end
end

def startGUI(user)
	if File.exists?(@gui)
		link = '<a href="http://sites.google.com/site/gruenanet/pdms/runpdms" target="_blank">pdms.gruena.net</a>'
		system("copy /Y runPDMS.png #{@temp}\\runPDMS.png")
		gui = "#{Dir.pwd}/" + @gui
		File.open(gui, "r+") do |f|
			@lines = f.readlines
		end
		getProj(user)	
		@lines.each do |line|
			if line =~ /winuser/
				line.gsub!(/winuser/, user)
			end
			if line =~ /<!-- PROFILES -->/
				profiles = ""
				@projects.each do |proj|
					proj = proj[:name] if @admin
					proj = proj[:profile] if !@admin
					if proj == @last[:profile]
						prof = "<option value=" + '"' + proj + '"' + " selected>#{proj}</option>"
					else	
						prof = "<option value=" + '"' + proj + '"' + ">#{proj}</option>"
					end
					profiles << "#{prof}\n"
				end
				line.gsub!(/<!-- PROFILES -->/, profiles)
			end
			if line =~ /<!--LOGO-->/
				line.gsub!(/<!--LOGO-->/, link) if @logo
			end
		end
		newgui = @temp + "\\" + @gui
		File.open(newgui, "w+") do |f|
			@lines.each do |l|
				f.puts l
			end
		end
		system("start #{newgui}")
	else
		log("GUI missing.")
	end
	exit
end
	
def startPDMS(profile)
	log("#{profile}")
	isAdmin(@user)
	p = @db[:profile].filter(:name => profile).first
	start = "#{p[:cmd]} #{p[:code]} #{p[:puser]}/#{p[:pwd]} /#{p[:mdb]} #{p[:module]}"
	log(start)
	File.open(@script, "w") {|f| f.puts start}
	profiles = @db[:user_profile]
	if @admin
		profiles.filter(:user => @user, :last => 1).update(:profile => profile)
	else
		profiles.filter(:user => @user, :last => 1).update(:last => 0)
		profiles.filter(:user => @user, :profile => profile).update(:last => 1)
	end
	system("call #{@script}")
end

config()
@user = ENV["USERID"]
#~ @user = "MCOT"

args = case ARGV[0]
	when nil then startGUI(@user)
	else
		prof = ARGV[0]
		startPDMS(prof)
end

if @clean
	Dir.chdir(@temp)
	Dir.glob('runPDMS.*').each { |f| File.delete(f) }
end