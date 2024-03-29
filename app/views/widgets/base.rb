class Views::Widgets::Base < Erector::Widget # Erector::RailsWidget
  include Views::Widgets::WidgetHelper
  include Views::Widgets::WidgetCallerHelper
  include Views::Widgets::Gizmo::GizmoHelper

  delegate :current_object, :current_collection, :to => :"controller.rest_run"
  delegate :url_for, :dom_id, :dom_class, :to => :controller
end