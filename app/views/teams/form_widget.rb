class Views::Teams::FormWidget < Views::Widgets::Base

  def content
    form_for current_object do |f|
      helpers.field_set_with_control_for current_object do
        f.label :name
        f.text_field :name
        f.submit
      end
    end
  end

end