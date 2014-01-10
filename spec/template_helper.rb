require 'tempfile'
require 'fileutils'
require 'puppet'

def with_mock_user_template(content = 'Here is a <%= options[:variable] %>', name='foo', scripts_dir_name='scripts')
  tmp_scripts_dir = File.join(Dir.tmpdir, scripts_dir_name)
  FileUtils.mkdir(tmp_scripts_dir) unless File.exists?(tmp_scripts_dir)

  template_tempfile = Tempfile.open([name, '.erb'], tmp_scripts_dir)

  begin
    template_tempfile.write(content)
    template_tempfile.close
    Puppet[:confdir] = File.dirname(tmp_scripts_dir)

    yield File.basename(template_tempfile.path, '.erb')
  ensure
    # cleanup
    template_tempfile.unlink
    FileUtils.rmdir(tmp_scripts_dir)
  end
end
