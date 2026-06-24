require 'json'
require 'digest'

manifest = {}
Dir.glob("**/*.skp").each do |file_path|
  file_hash = Digest::SHA256.file(file_path).hexdigest
  chuoi_duong_dan = file_path.gsub("\\", "/")
  manifest[chuoi_duong_dan] = file_hash
end

File.open("NTV_manifest.json", "w") do |f|
  f.write(JSON.pretty_generate(manifest))
end
puts "Da tu dong tao file NTV_manifest.json thanh cong tren GitHub Server!"
