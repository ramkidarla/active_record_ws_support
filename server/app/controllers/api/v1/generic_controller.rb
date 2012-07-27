# -*- encoding : utf-8 -*-
class Api::V1::GenericController < Api::V1::BaseController
  def get_model_name
    #params[:model_name].classify.constantize
    eval(params[:model_name].classify)
  end

  def fields
    _model = get_model_name
    json_string = _model.columns.map{|f| {:name => f.name,  :type => f.type, :default => f.default, :null => f.null, :primary => f.primary}.to_json}
    
    if _model.respond_to?('local_fields_json')
      json_string = json_string + _model.local_fields_json
    end
    respond_to do |format|
      format.json { render :json => json_string }
    end
  end

  def select
    sql = params[:sql]
    objs = get_model_name.find_by_sql(sql)

    respond_to do |format|
      format.json { render :json => objs.to_json }
    end
  end

  def invoke
    obj = get_model_name.find(params[:id])
    params[:attributes].each do |attr, value|
      obj[attr] =value
    end if params[:attributes].present?
    
    result = obj.send(params[:operation])
    respond_to do |format|
      format.json {  render :json => "{\"#{params[:operation]}\":#{result}}"  }
    end
  end

  def show
    obj = get_model_name.find(params[:id])
    respond_to do |format|
      format.json { render :json => obj }
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
      format.json { head :ok, :status => 200 }
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
        record = User.new(params[:attributes])
        valid_flag = record.valid?
      end

      if valid_flag
        format.json { head :ok, :status => 200 }
      else
        format.json do
          render :json => record.errors, :status => 400
        end
      end
    end
  end
end