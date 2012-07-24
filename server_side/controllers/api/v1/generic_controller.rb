# -*- encoding : utf-8 -*-
class Api::V1::GenericController < Api::V1::BaseController
  
 def get_model_name
    eval(params[:model_name])
  end
  
  def schema_fields
    #json_string = params[:klass].camelize.constantize.columns.map{|f| f.to_json}
    json_string = get_model_name.columns.map{|f| f.to_json}
    json_string << '{"name":"password", "type":"string"}'
    json_string << '{"name":"password_confirmation", "type":"string"}'
    respond_to do |format|
      format.json { render :json => json_string }
    end
  end
  
  def select
    sql = params[:sql]
    users = get_model_name.find_by_sql(sql)
    
    respond_to do |format|
      format.json { render :json => users.to_json }
    end  
  end
  
  # def invoke
    # parsed = ActiveSupport::JSON.decode(request.body.read)
    # params = parsed["params"]
    # operation = parsed["operation"]
#     
    # @params = HashWithIndifferentAccess.new(params)
#     
    # send(operation)
    # #self.response_body =  proc do |response, output|
    # #end
  # end
  
#private
  # def index
    # offset = @params[:page].to_i-1 if @params[:page]
    # @users = User.find(:all, :conditions => @params[:conditions],
                       # :order => @params[:order_by] || @params[:order],
                       # :joins => @params[:join] || @params[:joins], 
                       # :include => @params[:include],
                       # :select => @params[:select], 
                       # :limit => @params[:per_page], :offset => offset)
    # respond_to do |format|
      # format.json { render :json => "{\"collection\":#{@users.to_json}, \"total\":#{@users.size}}" }
    # end
  # end
  
  def show
    @record = get_model_name.find(params[:id])
    #@user = User.find(@params[:id])
    respond_to do |format|
      format.json { render :json => @record }
    end
  end
  
  def create
    respond_to do |format|
      record = get_model_name.new(params[:attributes])
      if record.save
        format.json { 
          render :json => record.to_json, :status => 200 
        }
      else
        format.json do
          render :json => record.errors, :status => 400
        end
      end
    end
  end
  
  def update
    record = get_model_name.find(params[:id])
    
    respond_to do |format|
      if record.update_attributes(params[:attributes])
        format.json { head :ok, :status => 200 }
      else
        format.json do
          render :json => record.errors, :status => 400
        end
      end
    end
  end
  
  #put
  def destroy
    record = get_model_name.find(params[:id])
    record.destroy
    
    respond_to do |format|
      format.json { head :ok, :status => 200  }
    end
  end
  
  def valid
    respond_to do |format|
      
      if params[:id].present?
        record = get_model_name.find(params[:id])
        params[:attributes].each do |attr, value|
           record[attr] =value 
        end
        valid_flag = record.valid?
      else
        user = User.new(params[:attributes])
        valid_flag = record.valid?
      end
      
      if valid_flag
        format.json { head :ok, :status => 200  }
      else
        format.json do
          render :json => record.errors, :status => 400
        end
      end
    end
  end
end