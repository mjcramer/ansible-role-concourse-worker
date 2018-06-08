require_relative '../../helper_spec.rb'

describe user('concourse') do
  it { should exist }
end

describe group('concourse') do
  it { should exist }
end

