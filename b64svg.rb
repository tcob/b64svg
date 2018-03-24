#!/usr/bin/env ruby

require 'base64'
require 'image_optimizer'
require 'mini_magick'
require 'svgo_wrapper'
require 'optparse'
require 'fileutils'

quality = ARGV[0].nil? ? 50 : ARGV[0].to_i
backup = ARGV[1].nil? ? false : ARGV[1]

if backup == 'backup'
  backup = true
  budir = ENV['HOME'] + '/Desktop/SVGbackup/'
  puts 'Save option passed: backing up original files to ' + budir
end

if ARGV.empty?
  puts "Please specify at least a compression quality setting.\n\n"
  puts "Minimum usage:\n\n    b64svg.rb 50\n\n"
  puts 'This will compress files to 50% quality. For lower quality, use a lower number.'
  puts "To create backups of the original SVG, pass the 'backup' option:\n"
  puts "Example:\n\n    b64svg.rb 60 backup\n\n"
  exit
end

arr_compressed_jpegs = []
arr_encoded = []

svgs = File.join('**', '*.svg')
input_files = Dir.glob(svgs)

input_files.each do |file_name|
  lc = 0 && ic = 0 && i = 0
  arr_encoded.clear
  arr_compressed_jpegs.clear

  File.read(file_name).each_line do |li|
    lc += 1
    # Add to array if line matches regex pattern for base64 encoded png
    arr_encoded.push li[%r{(?<=\/png;base64,).*(?=\")}] if li[%r{(?<=\/png;base64,).*(?=\")}] && ic += 1
  end

  if ic > 0
    puts "\nFound " + ic.to_s + ' embedded images in ' + file_name.to_s
    puts ' -- SVG size: ' + (File.size(file_name).to_f / 1024).round(2).to_s + ' KB'
    ic = 0
    svgo = SvgoWrapper.new

    output_SVG = file_name + 'comp'
    File.delete(output_SVG) if File.exist?(output_SVG)

    arr_encoded.each do |encoded|
      ic += 1
      decoded = Base64.decode64(encoded)
      number = ic.to_s
      png = file_name + number + '.png'
      jpeg = file_name + number + '.jpg'

      File.open(png, 'wb') do |f|
        f.write(decoded)
      end

      image = MiniMagick::Image.open(png)
      image.flatten
      image.format 'jpg'
      image.write jpeg
      ImageOptimizer.new(jpeg, quality: quality).optimize

      # read contents of file, not just encode the filename
      data = File.open(jpeg, 'rb', &:read)
      encodedjpg = Base64.encode64(data)
      arr_compressed_jpegs.push encodedjpg

      File.delete(png)
      File.delete(jpeg)
    end

    # Replace with indexed string if pattern found
    File.open(file_name).each_line do |li|
      if li[/(?<=\/png;base64,).*=?(?=\")/]
        jpeg_index = arr_compressed_jpegs[i]
        regex = li.gsub(/png;base64,.*(?=\")/, "jpg;base64,#{jpeg_index}")
        File.open(output_SVG, 'a') { |f| f.write(regex) }
        i += 1
      else File.open(output_SVG, 'a') { |f| f.write(li) }
        end
    end

    # original SVG size, end SVG size
    osize = (File.size(file_name).to_f / 1024).round(2)
    esize = (File.size(output_SVG).to_f / 1024).round(2)

    puts 'DONE. ' + file_name.to_s + ' - ' + osize.to_s + ' KB --> ' + esize.to_s + ' KB'
    puts 'Filesize (before SVG compression) reduced by'
    puts (osize - esize).round(2).to_s + ' KB. (' + (100 - (esize / osize) * 100).round(2).to_s + '%).\n\n'

    if backup == true
      Dir.mkdir(budir) unless File.exist?(budir)
      t = (Time.now.to_f * 1000).to_i.to_s
      FileUtils.cp(file_name, budir + t + '-' + file_name)
    else
      File.delete(file_name)
    end
    File.rename(output_SVG, file_name)
    formatted = svgo.optimize_images_data(File.read(file_name))
    File.open(file_name, 'w') { |f| f.write(formatted) }
  else
    puts 'No embedded PNGs found, skipping ' + file_name
  end
end
