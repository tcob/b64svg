#!/usr/bin/env ruby

require "base64"
require "image_optimizer"
require "mini_magick"
require "svgo_wrapper"

ARGV[0].nil? ? quality = 50 : quality = ARGV[0].to_i

if ARGV.empty?
  puts "Using default quality of 50%. Set using script.rb 1-100 (lowest quality to highest quality)"
end

arr_encoded = []
arr_compressed_jpegs = []

svgs = File.join("**", "*.svg")
# change to **/*.svg or use ARGV
input_files = Dir.glob(svgs)

input_files.each do |file_name|
  # init counters for line count, image count and indexing of compressed images
  lc = 0 && ic = 0 && i = 0
  # clear
  arr_encoded.clear
  arr_compressed_jpegs.clear

    File.read(file_name).each_line do |li|      
      lc = lc + 1
      # Add to array if line matches regex pattern for base64 encoded png
      arr_encoded.push li[/(?<=\/png;base64,).*(?=\")/] if li[/(?<=\/png;base64,).*(?=\")/] && ic = ic + 1
    end 

  # Continue only if at least one embedded image found
  if ic > 0
    puts "Found " + ic.to_s + " embedded images in " + file_name.to_s + " -- SVG size: " + (File.size(file_name).to_f / 1024).round(2).to_s + " KB"
    ic = 0

    svgo = SvgoWrapper.new

    # name outfile file and remove if already existing
    output_SVG = file_name + "comp"
    File.delete(output_SVG) if File.exist?(output_SVG)

    arr_encoded.each { |encoded|
      ic = ic + 1
      decoded = Base64.decode64(encoded)
      number = ic.to_s
      png = file_name + number + ".png"
      jpeg = file_name + number + ".jpg"
      
      File.open(png, "wb") do |f|
        f.write(decoded)
      end

      image = MiniMagick::Image.open(png)
      image.flatten
      image.format "jpg"
      image.write jpeg
      ImageOptimizer.new(jpeg, quality: quality).optimize

      # read contents of file, not just encode the filename
      data = File.open(jpeg, "rb") {|io| io.read}
      encodedjpg = Base64.encode64(data)
      arr_compressed_jpegs.push encodedjpg
      File.delete(png)
      File.delete(jpeg)
    }

    # Replace with indexed string if pattern found
    File.open(file_name).each_line do |li|
      if li[/(?<=\/png;base64,).*=?(?=\")/]
        jpeg_index = arr_compressed_jpegs[i]
        regex = li.gsub(/png;base64,.*(?=\")/, "jpg;base64,#{jpeg_index}")                
        File.open(output_SVG, 'a') { |f| f.write(regex) }
          i = i + 1
        else File.open(output_SVG, 'a') { |f| f.write(li) }
        end
    end

    # original SVG size, end SVG size
    osize = (File.size(file_name).to_f / 1024).round(2)
    esize = (File.size(output_SVG).to_f / 1024).round(2)

    puts "Done. " + file_name.to_s + " - " + osize.to_s + " KB --> " + esize.to_s + " KB"
    puts "Filesize compressed by " + (osize - esize).round(2).to_s + " KB. (" + ( 100 - (esize / osize) * 100).round(2).to_s + "%)."
    
    # add if argv / command to activate this
    File.delete(file_name)
    File.rename(output_SVG, file_name)

    puts "Formatting compressed SVGs."
    formatted = svgo.optimize_images_data(File.read(file_name))
    File.open(file_name, 'w') { |f| f.write(formatted)}
  end
end
