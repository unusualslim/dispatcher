require 'net/ftp'

module PdiFtpConcern
  extend ActiveSupport::Concern

  def ftp_connect
    Net::FTP.open(
      ENV.fetch('PDI_FTP_HOST'),
      username: ENV.fetch('PDI_FTP_USER'),
      password: ENV.fetch('PDI_FTP_PASSWORD')
    ) do |ftp|
      ftp.passive = true
      yield ftp
    end
  end

  def ftp_find_file(ftp, dir, extensions, patterns)
    ftp.chdir(dir)
    files = ftp.nlst.select { |f| extensions.any? { |ext| f.downcase.end_with?(ext) } }
    raise "No #{extensions.join('/')} files found in #{dir}" if files.empty?

    match = patterns.lazy.filter_map do |pattern|
      files.find { |f| File.basename(f).match?(pattern) }
    end.first

    raise "No matching file found in #{dir} (files: #{files.join(', ')})" unless match
    match
  end

  def ftp_download_text(ftp, filename)
    content = StringIO.new
    ftp.retrbinary("RETR #{filename}", Net::FTP::DEFAULT_BLOCKSIZE) { |chunk| content << chunk }
    content.string
  end

  def ftp_download_tempfile(ftp, filename)
    ext      = File.extname(filename)
    tempfile = Tempfile.new(['pdi_import', ext])
    tempfile.binmode
    ftp.retrbinary("RETR #{filename}", Net::FTP::DEFAULT_BLOCKSIZE) { |chunk| tempfile.write(chunk) }
    tempfile.rewind
    tempfile
  end

  def ftp_delete(ftp, filename)
    ftp.delete(filename)
    Rails.logger.info "[PdiFtp] Deleted #{filename} from FTP"
  rescue => e
    Rails.logger.warn "[PdiFtp] Could not delete #{filename}: #{e.message}"
  end
end
