#!/usr/bin/env ruby

require 'fileutils'
require 'cgi' # for escapeHTML
# basically gem install rails
require 'action_view'
include ActionView::Helpers::TagHelper
include ActionView::Helpers::SanitizeHelper

class State
  def initialize
    @files_and_mtimes = {}
  end

  def self.load(file)
    if File.exist?(file)
      result = State.new
      begin
        lines = File.readlines(file)
        lines.each do |line|
          mtime, name = line.split(' ')
          result.set_file_mtime(name, mtime.to_i)
        end
        result
      rescue
        puts "Warning: failed to read state file: #{$!}"
        self.new
      end
    else
      self.new
    end
  end

  def save!(file)
    write_via_tempfile(file, 'wb') do |f|
      @files_and_mtimes.each_pair do |filename, mtime|
        f.puts "#{mtime} #{filename}"
      end
    end
  end

  def saved_file_mtime(file)
    @files_and_mtimes[file] || 0
  end

  def set_file_mtime(file, mtime)
    @files_and_mtimes[file] = mtime.to_i
  end
end

# from https://github.com/tenderlove/rails_autolink/blob/master/lib/rails_autolink/helpers.rb
WORD_PATTERN = RUBY_VERSION < '1.9' ? '\w' : '\p{Word}'
BRACKETS = { ']' => '[', ')' => '(', '}' => '{' }
AUTO_LINK_RE = %r{
    (?: ((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):)// | www\. )
    [^\s<\u00A0"]+
  }ix
AUTO_LINK_CRE = [/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]

# Detects already linked context or position in the middle of a tag
def auto_linked?(left, right)
  (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
    (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
end

def auto_link_urls(text, html_options = {}, options = {})
  link_attributes = html_options
  text.gsub(AUTO_LINK_RE) do
    scheme, href = $1, $&
      punctuation = []

    if auto_linked?($`, $')
      # do not change string; URL is already linked
      href
    else
      # don't include trailing punctuation character as part of the URL
      while href.sub!(/[^#{WORD_PATTERN}\/-=&]$/, '')
        punctuation.push $&
          if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
            href << punctuation.pop
            break
        end
      end

      link_text = block_given?? yield(href) : href
      href = 'http://' + href unless scheme

      unless options[:sanitize] == false
        link_text = sanitize(link_text)
        href      = sanitize(href)
      end
      content_tag(:a, link_text, link_attributes.merge('href' => href), !!options[:sanitize]) + punctuation.reverse.join('')
    end
  end
end
def header(log_file_name)
<<EOS
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>#{h(log_file_name)}</title>
  <style>
    body { font-family: monospace; }
    .time { color: #0066A1; margin-right: 1em; }
  </style>
</head>
<body>
EOS
end

def footer
<<EOS
</body>
</html>
EOS
end

def index_header
<<EOS
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>IRC logs</title>
</head>
<body>
  <h1>IRC logs</h1>
  <ul>
EOS
end

def index_footer
<<EOS
  </ul>
</body>
</html>
EOS
end

def h(text)
  CGI::escapeHTML(text)
  auto_link_urls(text)
end

def write_via_tempfile(path, mode, &block)
  temp_path = path + ".tmp" + (rand * 1000000000).to_i.to_s
  begin
    File.open(temp_path, mode, &block)
    File.rename(temp_path, path)
  ensure
    File.unlink(temp_path) if File.exist?(temp_path)
  end
end

def transform_file(srcfile, destfile, src_encoding)
  File.open(srcfile, "rb:" + src_encoding) do |sf|
    write_via_tempfile(destfile, "wb:UTF-8") do |df|
      df.puts header(File.basename(srcfile))
      sf.each_line do |line|
        line = line.encode('UTF-8')
        if line =~ /^\[(\d+):(\d+):(\d+)\](.*)$/
          time = "#{$1}:#{$2}"
          text = $4
          df.puts '<div><span class="time">' + time + '</span><span class="msg">' + h(text) + '</span></div>'
        else
          df.puts h(line)
        end
      end
      df.puts footer
    end
  end
end

def write_index(index_file, files)
  files = files.reverse
  write_via_tempfile(index_file, "wb:UTF-8") do |f|
    f.puts index_header
    files.each do |log_file_path|
      log_file_name = File.basename(log_file_path)
      html_file_name = "#{File.basename(log_file_name)}.html"
      if log_file_name =~ /^(.*)\.log\.(\d{4})(\d{2})(\d{2})/
        channel = $1
        year, month, day = [$2, $3, $4].map(&:to_i)
        link_text = "##{channel} #{year}-#{sprintf '%02d', month}-#{sprintf '%02d', day}"
      else
        link_text = html_file_name
      end
      f.puts('<li><a href="' + h(html_file_name) + '">' + h(link_text) + '</a></li>')
    end
    f.puts index_footer
  end
end


if ARGV.include?('-h') || ARGV.include?('--help') || ARGV.length < 1
  puts "Usage: #{$0} destdir files..."
  exit
end

dest_dir = ARGV[0]
files = ARGV[1..-1].sort
log_encoding = 'ISO8859-15'
state_file = "#{dest_dir}/.irc-log-htmlizer.state"

FileUtils.mkdir_p(dest_dir)

state = State.load(state_file)

mtimes = Hash[files.map {|f| [f, File.mtime(f).to_i] }]
changed_files = files.select {|f| mtimes[f] != state.saved_file_mtime(f) }

changed_files.each do |src_file|
  dest_file = dest_dir + '/' + File.basename(src_file) + '.html'
  puts "Writing #{dest_file}"
  transform_file(src_file, dest_file, log_encoding)
  state.set_file_mtime(src_file, File.mtime(src_file))
end

index_file = dest_dir + '/index.html'
puts "Writing #{index_file}"
write_index(index_file, files)
state.save!(state_file)
