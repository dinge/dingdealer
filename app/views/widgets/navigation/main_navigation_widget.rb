class Views::Widgets::Navigation::MainNavigationWidget < Views::Widgets::Base

  def content
    control_list_container :id => :main_navigation, :class => :navigation do
      [

        helpers.link_to('triples',
          tools_phrase_maker_triples_path,
          :class => dom_class_for_active_gizmo(:triples, controller.controller_name),
          :accesskey => 't'),

        helpers.link_to('phrases',
          tools_phrase_maker_phrases_path,
          :class => dom_class_for_active_gizmo(:phrases, controller.controller_name),
          :accesskey => 't'),

        helpers.link_to('things',
          things_path,
          :class => dom_class_for_active_gizmo(:things, controller.controller_name),
          :accesskey => 't'),

        helpers.link_to('concepts',
          concepts_path,
          :class => dom_class_for_active_gizmo(:concepts, controller.controller_name),
          :accesskey => 'c'),

        helpers.link_to('tags',
          tags_path,
          :class => dom_class_for_active_gizmo(:tags, controller.controller_name),
          :accesskey => 'a'),

        helpers.link_to('users',
          users_path,
          :class => dom_class_for_active_gizmo(:users, controller.controller_name),
          :accesskey => 'u'),

        helpers.link_to('teams',
          teams_path,
          :class => dom_class_for_active_gizmo(:teams, controller.controller_name))
      ]
    end
  end

end