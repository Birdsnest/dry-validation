# frozen_string_literal: true

RSpec.describe Dry::Validation::Result do
  describe '#inspect' do
    let(:params) do
      double(:params, message_set: [], to_h: { email: 'jane@doe.org' })
    end

    it 'returns a string representation' do
      result = Dry::Validation::Result.new(params) do |r|
        r.add_error(Dry::Validation::Message.new('not valid', path: :email))
      end

      expect(result.inspect).to eql('#<Dry::Validation::Result{:email=>"jane@doe.org"} errors={:email=>["not valid"]}>')
    end
  end

  describe '#errors' do
    subject(:errors) { result.errors }

    let(:params) do
      double(:params, message_set: [], to_h: { email: 'jane@doe.org' })
    end

    let(:result) do
      Dry::Validation::Result.new(params) do |r|
        r.add_error(Dry::Validation::Message.new('root error', path: [nil]))
        r.add_error(Dry::Validation::Message.new('email error', path: [:email]))
      end
    end

    describe '#[]' do
      it 'returns error messages for the provided key' do
        expect(errors[:email]).to eql(['email error'])
      end

      it 'returns [] for base errors' do
        expect(errors[nil]).to eql(['root error'])
      end
    end
  end

  describe '#error?' do

    let(:params) do
      double(:params, message_set: [], to_h: { email: 'jane@doe.org', blank: '' })
    end

    let(:result) do
      Dry::Validation::Result.new(params) do |r|
        r.add_error(Dry::Validation::Message.new('email error', path: [:email]))
      end
    end

    it 'returns true for an error from the schema' do
      allow(params).to receive(:error?).
        with(:blank).
        and_return(true)

      expect(result.error?(:blank)).to be true
    end

    it 'returns true for an error added by the validation' do
      allow(params).to receive(:error?).
        with(:email).
        and_return(false)

      expect(result.error?(:email)).to be true
    end
  end

  describe '#inspect' do
    let(:params) do
      double(:params, message_set: [], to_h: {})
    end

    let(:context) do
      context = Concurrent::Map.new
      context[:data] = 'foo'
      context
    end

    let(:result) do
      Dry::Validation::Result.new(params, context)
    end

    example 'results are inspectable' do
      expect(result.inspect).to be_a(String)
    end
  end
end
