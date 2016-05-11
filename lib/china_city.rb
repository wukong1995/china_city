# encoding: utf-8
require "china_city/engine"

module ChinaCity
  CHINA = '000000' # 全国
  PATTERN = /(\d{2})(\d{2})(\d{2})/

  class << self
    # @options[:show_all] 是否显示港澳台这三处敏感地区
    def list(parent_id, options = {})
      parent_id ||= '000000'
      show_all = options[:show_all] || false

      result = []
      return result if parent_id.blank?
      province_id = province(parent_id)
      city_id     = city(parent_id)
      district_id = district(parent_id)
      children = data show_all
      children = children[province_id][:children] if children.has_key?(province_id)
      children = children[city_id][:children] if children.has_key?(city_id)
      children = children[district_id][:children] if children.has_key?(district_id)
      children.each_key do |id|
        result.push [children[id][:text], id]
      end

      #sort
      result.sort! {|a, b| a[1] <=> b[1]}
      result
    end

    # @options[:prepend_parent] 是否显示上级区域
    def get(id, options = {})
      return '' if id.blank?
      prepend_parent = options[:prepend_parent] || false
      # 补全areas.json中的数据后，可兼容港澳台下的children信息
      children = data true
      return children[id][:text] if children.has_key?(id)
      province_id = province(id)
      province_text = children[province_id][:text]
      children = children[province_id][:children]
      return "#{prepend_parent ? province_text : ''}#{children[id][:text]}" if children.has_key?(id)
      city_id = city(id)
      city_text = children[city_id][:text]
      children = children[city_id][:children]
      return "#{prepend_parent ? (province_text + city_text) : ''}#{children[id][:text]}" if children.has_key?(id)
      district_id = district(id)
      district_text = children[district_id][:text]
      children = children[district_id][:children]
      return "#{prepend_parent ? (province_text + city_text + district_text) : ''}#{children[id][:text]}"
    end

    def province(code)
      match(code)[1].ljust(6, '0')
    end

    def city(code)
      id_match = match(code)
      "#{id_match[1]}#{id_match[2]}".ljust(6, '0')
    end

    def district(code)
      code[0..5].rjust(6,'0')
    end

    def data show_all=false
      @list_all ||= list_data true
      @list ||= list_data

      show_all ? @list_all : @list
    end

    def list_data show_all=false
      list = {}
      #@see: https://github.com/cn/GB2260
      json = JSON.parse(File.read("#{Engine.root}/db/areas.json"))
      streets = json.values.flatten
      streets.each do |street|
        # skip sensitive areas when show_all is false
        next if (!show_all && street['sensitive_areas'])

        id = street['id']
        text = street['text']
        if id.size == 6    # 省市区
          if id.end_with?('0000')                           # 省
            list[id] =  {:text => text, :children => {}}
          elsif id.end_with?('00')                          # 市
            province_id = province(id)
            list[province_id] = {:text => nil, :children => {}} unless list.has_key?(province_id)
            list[province_id][:children][id] = {:text => text, :children => {}}
          else
            province_id = province(id)
            city_id     = city(id)
            list[province_id] = {:text => text, :children => {}} unless list.has_key?(province_id)
            list[province_id][:children][city_id] = {:text => text, :children => {}} unless list[province_id][:children].has_key?(city_id)
            list[province_id][:children][city_id][:children][id] = {:text => text, :children => {}}
          end
        else               # 街道
          province_id = province(id)
          city_id     = city(id)
          district_id = district(id)
          list[province_id] = {:text => text, :children => {}} unless list.has_key?(province_id)
          list[province_id][:children][city_id] = {:text => text, :children => {}} unless list[province_id][:children].has_key?(city_id)
          list[province_id][:children][city_id][:children][district_id] = {:text => text, :children => {}} unless list[province_id][:children][city_id][:children].has_key?(district_id)
          list[province_id][:children][city_id][:children][district_id][:children][id] = {:text => text}
        end
      end
      list
    end

    def match(code)
      code.match(PATTERN)
    end
  end
end
