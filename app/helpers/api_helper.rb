module ApiHelper
  def attribute_line(attr, details)
    content_tag('li') do
      content_tag('mark', attr) + ': ' + details
    end
  end

  def api_title_route(title, route)
    content_tag(:h3, title) + content_tag(:h3) { content_tag(:code, route) }
  end
end
