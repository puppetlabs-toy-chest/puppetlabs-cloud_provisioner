require 'facter'

Facter.add('puppet_install_dir') do
  setcode do
    $LOAD_PATH.find { |loc| File.exists? "#{loc}/puppet.rb" }
  end
end
