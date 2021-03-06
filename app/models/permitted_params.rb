class PermittedParams < Struct.new(:params)

  def search
    [term, filters]
  end

  def term
    params[:q] || ''
  end

  def filters(options = {})
    filters = params.map do |key, value|
      case key
      when *(%w(before after))
        if !options[:ignore_dates].present?
          date = date_from_params(value, end: key == 'before')
          [key, date] unless date.nil?
        end
      when *(%w(type language subject country state place provider partner))
        [key, value]
      end
    end
    filters.compact.inject({}) { |h, e| h[e.first.to_sym] = e.last; h }
  end

  def args
    args = params.map do |key, value|
      case key
      when 'page'       then [key, value]
      when 'page_size'  then [key, value] if %w(10 20 50 100).include?(value)
      when 'sort_by'    then [key, value] if %w(subject created).include?(value)
      when 'sort_order' then [key, value] if %w(asc desc).include?(value)
      end
    end
    args.compact.inject({}) { |h, e| h[e.first.to_sym] = e.last; h }
  end

  def date_from_params(date, options = {})
    if date.is_a? Hash and date[:year].present?
      month = date[:month].present? ? date[:month] : (options[:end] ? '12' : '1')
      day   = date[:day].present?   ? date[:day]   : (options[:end] ? '31' : '1')
      Date.new *[date[:year], month, day].map(&:to_i) rescue nil
    end
  end

end