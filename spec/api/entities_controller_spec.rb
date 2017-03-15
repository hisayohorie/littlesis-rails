require 'rails_helper'

describe Api::EntitiesController, type: :controller do
  describe 'show' do
    context 'good request' do
      ATTRIBUTE_KEYS = %w(name blurb summary website parent_id primary_ext updated_at start_date end_date link_count)
      before(:all)  { @pac = create(:pac) }
      before(:each) do
        get :show, id: @pac.id
        @json = JSON.parse(response.body)
      end

      it { should respond_with(200) }

      it 'is json' do
        expect(response.content_type).to eql 'application/json'
      end

      it 'has meta info' do
        ['copyright', 'license', 'apiVersion'].each do |k|
          expect(@json['meta'].key?(k)).to be true
        end
      end

      it 'sets type to be entities' do
        expect(@json['data']['type']).to eql 'entities'
      end

      it 'sets correct id' do
        expect(@json['data']['id']).to eql @pac.id
      end

      it 'has correct attribute keys' do
        ATTRIBUTE_KEYS.each { |k|expect(@json['data']['attributes'].key?(k)).to be true }
        expect(@json['data']['attributes']['name']).to eql 'PAC'
        expect(@json['data']['attributes']['primary_ext']).to eql 'Org'
      end

      it 'has url link' do
        expect(@json['data']['links'].key?('self')).to be true
      end

      it 'does not include extensions information' do
        expect(@json['data']['attributes'].key?('extensions')).to be false
      end
    end

    context 'record not found' do
      before { get :show, id: 100000000 }
      it { should respond_with(404) }
    end

    context 'record deleted' do
      before do
        @deleted_pac = create(:pac, is_deleted: true)
        get :show, id: @deleted_pac
      end
      it { should respond_with(410) }
    end

    context 'request details' do
      before(:all) do
        @business_person = create(:person, name: 'business person')
        @business_person.add_extension('BusinessPerson', sec_cik: 12345)
      end

      before(:each) do
        get :show, { id: @business_person.id, details: 'TRUE' }
        @json = JSON.parse(response.body)
      end

      it { should respond_with(200) }

      it 'is json' do
        expect(response.content_type).to eql 'application/json'
      end

      it 'includes extensions' do
        expect(@json['data']['attributes'].key?('extensions')).to be true
      end

      it 'includes Person and BusinessPerson info' do
        expect(@json['data']['attributes']['extensions'].key?('Person')).to be true
        expect(@json['data']['attributes']['extensions'].key?('BusinessPerson')).to be true
      end

      it 'has correct sec_cik in response' do
        expect(@json['data']['attributes']['extensions']['BusinessPerson']['sec_cik']).to eql 12345
      end
    end
  end # end show

  describe '/entities/:id/extensions' do
    before(:all) do
      @entity = create(:org)
      @entity.add_extension('PoliticalFundraising')
    end

    before(:each) do
      get :extensions, id: @entity.id
      @json = JSON.parse(response.body)
    end

    it { should respond_with(200) }

    it 'data and meta keys' do
      expect(@json.key?('meta')).to be true
      expect(@json.key?('data')).to be true
    end

    it 'returns extension definitions in data as array' do
      expect(@json['data']).to be_a Array
      expect(@json['data'].length). to eql 2
    end
  end
end
