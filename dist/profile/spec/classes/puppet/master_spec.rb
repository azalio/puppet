require 'spec_helper'

describe 'profile::puppet::master' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) { facts.merge(aws_assets_bucket: 'my_bucket') }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('profile::puppet::master') }
        it { is_expected.to contain_class('hiera') }

        it { is_expected.to contain_class('r10k') }
        it do
          is_expected
            .to contain_exec('R10K deploy environment')
            .with_command('r10k deploy environment --puppetfile --verbose')
            .with_refreshonly(true)
        end
      end
    end
  end
end
