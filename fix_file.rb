code = File.read("C:/Users/QUYNGUYEN/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins/ntv/src/find_component.rb")

target_start = "                    when \"online2\" then \"NTV_online2_cache\"\n"
target_end = "          b_models = []\n"

idx_start = code.index(target_start)
idx_end = code.index(target_end, idx_start) + target_end.length

if idx_start.nil? || idx_end.nil?
  puts "Could not find anchors"
  exit
end

replacement = <<~RUBY
                    when "online2" then "NTV_online2_cache"
                    when "vach_cnc" then "NTV_vachcnc_cache"
                    end

      # [TỐI ƯU 1]: KIỂM TOÁN CACHE SIÊU TỐC VÀ TỰ ĐỘNG CHỤP BÙ ẢNH BỊ MẤT
      unless b_lam_moi
        b_cache = self.pt_doc_du_lieu("NTV_THU_VIEN_CFG", b_cache_key, nil)
        if b_cache && !b_cache.empty?
          b_co_thay_doi = false
          b_thu_muc_thumb = if b_loai == "online"
                              File.join(self.pt_khoi_tao_thu_muc_thu_vien[:base], 'online_thumb')
                            elsif b_loai == "online2"
                              File.join(self.pt_khoi_tao_thu_muc_thu_vien[:base], 'online2_thumb')
                            else
                              self.pt_thu_muc_cache_anh
                            end
          b_tien_to = b_loai == "material" ? "mat_" : ""
          @b_hang_doi_anh ||= []
          
          b_cache.each do |b_folder|
            b_models = b_folder["models"] || b_folder[:models] || []
            b_models.each do |b_model|
              b_path_skp = b_model["path"] || b_model[:path]
              next unless b_path_skp
              
              b_img_current = b_model["img"] || b_model[:img]
              b_path_fix = b_path_skp.gsub("\\\\", "/")
              
              if b_loai == "online" || b_loai == "online2" || b_loai == "vach_cnc"
                # CHẾ ĐỘ ONLINE: Ảnh được nạp trực tiếp từ Github URL (Không kiểm tra local)
                if b_img_current.to_s.strip.empty? || b_img_current == "NTV_SPINNER" || !b_img_current.include?("http")
                  b_path_img_git = b_path_fix.sub(/\\.skp$/i, '.jpg')
                  b_path_img_encoded = b_path_img_git.split('/').map { |p| URI.encode_www_form_component(p).gsub('+', '%20') }.join('/')
                  b_repo = b_loai == "online" ? C_GITHUB_REPO : (b_loai == "vach_cnc" ? C_GITHUB_REPO_VACHCNC : C_GITHUB_REPO2)
                  b_model["img"] = "https://raw.githubusercontent.com/\#{C_GITHUB_USER}/\#{b_repo}/main/\#{b_path_img_encoded}"
                  b_model["img_goc"] = ""
                  b_co_thay_doi = true
                end
              else
                b_ten_anh = self.pt_tao_ten_anh_hash(b_path_fix)
                b_anh_vong_lap = File.join(b_thu_muc_thumb, "\#{b_tien_to}\#{b_ten_anh}").gsub("\\\\", "/")
                
                if File.exist?(b_anh_vong_lap)
                  # Nếu ảnh đã có trên đĩa nhưng cache đang mù -> Chữa mù
                  if b_img_current == "NTV_SPINNER" || b_img_current == ""
                    b_model["img"] = "file:///\#{b_anh_vong_lap}?t=\#{File.mtime(b_anh_vong_lap).to_i}"
                    b_model["img_goc"] = ""
                    b_co_thay_doi = true
                  end
                else
                  # [CHỮA LÀNH TỰ ĐỘNG]: Nếu ảnh vật lý bị xóa, đưa về Spinner
                  if b_img_current != "NTV_SPINNER"
                    b_model["img"] = "NTV_SPINNER"
                    
                    # [MÓC ẢNH VẬT LIỆU]: Ép URL an toàn để HTML tự nén ảnh (bỏ Base64 chống crash)
                    if b_loai == "material"
                      b_url_truc_tiep = "file:///" + b_path_fix.split('/').map { |p| URI.encode_www_form_component(p).gsub('+', '%20') }.join('/')
                      b_model["img_goc"] = b_url_truc_tiep
                    else
                      b_model["img_goc"] = ""
                    end
                    b_co_thay_doi = true
                  end
                  
                  # [CHẶN LỖI API]: Chỉ đưa vào hàng đợi Ruby nếu là Component.
                  if b_loai != "material"
                    b_da_co_trong_hang_doi = @b_hang_doi_anh.any? { |item| item[:skp] == b_path_fix }
                    unless b_da_co_trong_hang_doi
                      b_id_anh = b_model["id_anh"] || b_model[:id_anh]
                      @b_hang_doi_anh << { :skp => b_path_fix, :jpg => b_anh_vong_lap, :id_anh => b_id_anh, :loai => b_loai }
                    end
                  end
                end
              end
            end
          end
          
          if b_co_thay_doi
            self.pt_luu_du_lieu("NTV_THU_VIEN_CFG", b_cache_key, b_cache)
            puts "NTV_LOG: Da am tham kiem toan va cap nhat cache \#{b_loai} luc khoi dong."
          end
          
          self.pt_xu_ly_hang_doi_anh if (b_loai == "component" || b_loai == "online" || b_loai == "online2" || b_loai == "vach_cnc") && @b_hang_doi_anh.any?
          
          return b_cache
        end
      end

      @b_hang_doi_anh ||= []
      
      b_excluded_key = b_loai == "component" ? "lib_excluded_paths" : "lib_excluded_paths_mat"
      b_excluded_paths = self.pt_doc_du_lieu("NTV_THU_VIEN_CFG", b_excluded_key, [])
      b_excluded_chuan = b_excluded_paths.map { |ex| ex.to_s.gsub("\\\\", "/").strip.downcase }

      if b_loai == "online" || b_loai == "online2" || b_loai == "vach_cnc"
        b_sync_dir = b_loai == "online" ? self.pt_khoi_tao_thu_muc_sync : (b_loai == "vach_cnc" ? self.pt_khoi_tao_thu_muc_sync_vachcnc : self.pt_khoi_tao_thu_muc_sync_2)
        b_state_file = File.join(b_sync_dir, b_loai == "online" ? 'NTV_sync_state.json' : (b_loai == "vach_cnc" ? 'NTV_sync_state_vachcnc.json' : 'NTV_sync_state_2.json'))
        
        b_git_files = {}
        if File.exist?(b_state_file)
          b_git_files = JSON.parse(File.read(b_state_file, encoding: 'UTF-8')) rescue {}
        end
        
        b_folders_map = {}
        b_git_files.keys.each do |b_path|
          b_path = self.pt_chuyen_encoding_utf8_an_toan(b_path)
          b_thu_muc_cha = File.dirname(b_path)
          b_folders_map[b_thu_muc_cha] ||= []
          b_folders_map[b_thu_muc_cha] << b_path
        end
        
        b_all_data = []
        b_index = 0
        b_folders_map.keys.sort.each do |b_thu_muc_cha|
          b_ten_thu_muc = b_thu_muc_cha.gsub("/", " - ")
          b_ten_thu_muc = b_loai == "online" ? "Thư viện Online 1" : (b_loai == "vach_cnc" ? "Vách CNC" : "Thư viện Online 2") if b_thu_muc_cha == "." || b_thu_muc_cha == "Thư viện Online" || b_thu_muc_cha == "Thư viện Online 2" || b_thu_muc_cha == "Vách CNC"
          
          b_models = []
RUBY

code = code[0...idx_start] + replacement + code[idx_end..-1]

File.write("C:/Users/QUYNGUYEN/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins/ntv/src/find_component.rb", code)
puts "Fix applied successfully"
