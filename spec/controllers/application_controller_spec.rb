require 'rails_helper'

describe ApplicationController, type: :controller do
  class TestController < ApplicationController
    def current_user
      FactoryGirl.build(:user, sf_guard_user_id: 1000)
    end
  end


  describe 'ParamsHelper' do
    describe 'blank_to_nil' do
      it 'converts blank strings to nil' do
        hash = { 'not_blank' => 'something', 'blank' => '' }
        expect(ApplicationController.new.send(:blank_to_nil, hash)).to eq({ 'not_blank' => 'something', 'blank' => nil })
      end

      it 'converts blank strings to nil for neseted hashes' do
        hash = { 'not_blank' => 'something', 'blank' => '', 'nested_attributes' => { 'somethingness' => 'yes', 'nothingness' => '' } }
        expect(ApplicationController.new.send(:blank_to_nil, hash))
          .to eq({ 'not_blank' => 'something', 'blank' => nil, 'nested_attributes' => { 'somethingness' => 'yes', 'nothingness' => nil } })
      end
    end

    describe 'is_current_helper' do
      it 'converts a yes value to true' do
        expect(ApplicationController.new.send(:is_current_helper, 'y')).to be true
        expect(ApplicationController.new.send(:is_current_helper, '1')).to be true
      end

      it 'converts a no value to false' do
        expect(ApplicationController.new.send(:is_current_helper, 'no')).to be false
        expect(ApplicationController.new.send(:is_current_helper, 'False')).to be false
      end

      it 'converts any other value to nil' do
        expect(ApplicationController.new.send(:is_current_helper, '')).to be nil
        expect(ApplicationController.new.send(:is_current_helper, 'NULL')).to be nil
        expect(ApplicationController.new.send(:is_current_helper, 'i can write anything here?')).to be nil
      end
    end

    describe 'prepare_update_params' do
      let(:params) do
        ActionController::Parameters.new({'start_date' => '1999'}).permit(:start_date)
      end

      it 'returns hash with last_user_id and converted dates' do
        result = TestController.new.send(:prepare_update_params, params)
        expect(result).to eq({ 'start_date' => '1999-00-00', 'last_user_id' => 1000 })
      end

      it 'returns HashWithIndifferentAccess' do
        result = TestController.new.send(:prepare_update_params, params)
        expect(result).to be_a ActiveSupport::HashWithIndifferentAccess
      end

      it 'handles input for is_current: true' do
        p = ActionController::Parameters.new({'start_date' => '1999', 'is_current' => 'YES'}).permit(:start_date, :is_current)
        result = TestController.new.send(:prepare_update_params, p)
        expect(result).to eq({'start_date' => '1999-00-00', 'last_user_id' => 1000, 'is_current' => true})
      end

      it 'handles input for is_current: missing' do
        p = ActionController::Parameters.new({'start_date' => '1999'}).permit(:start_date, :is_current)
        result = TestController.new.send(:prepare_update_params, p)
        expect(result).to eq({'start_date' => '1999-00-00', 'last_user_id' => 1000})
      end

      it 'handles input for is_current: nil' do
        p = ActionController::Parameters.new({'start_date' => '1999', 'is_current' => nil}).permit(:start_date, :is_current)
        result = TestController.new.send(:prepare_update_params, p)
        expect(result).to eq({'start_date' => '1999-00-00', 'last_user_id' => 1000, 'is_current' => nil})
      end
    end
  end

  describe 'errors' do
    describe 'permission errors' do
      controller do
        def index
          raise Exceptions::PermissionError
        end
      end
      before { get :index }
      it { should respond_with(403) }
      it { should render_template('errors/permission') }
    end

    describe 'NotFoundError' do
      controller do
        def index
          raise Exceptions::NotFoundError
        end
      end
      before { get :index }
      it { should respond_with(404) }
      it { should render_template('errors/not_found') }
    end

    describe 'RoutingError' do
      controller do
        def index
          raise ActionController::RoutingError.new('bad route')
        end
      end
      before { get :index }
      it { should respond_with(404) }
      it { should render_template('errors/not_found') }
    end

    describe 'RecordNotFound' do
      controller do
        def index
          raise ActiveRecord::RecordNotFound
        end
      end
      before { get :index }
      it { should respond_with(404) }
      it { should render_template('errors/not_found') }
    end
  end
end
