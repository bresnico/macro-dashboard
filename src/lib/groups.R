# Fonction de gestion des labels de groupes et sous-groupes

get_group_labels <- function(groups_config) {
  
  # Création d'une liste pour les labels de groupes
  group_labels <- tibble(
    group_id = names(groups_config),
    group_label = map_chr(groups_config, ~.x$label)
  )
  
  # Création d'une liste pour les labels de sous-groupes
  subgroup_labels <- tibble(
    group_id = rep(names(groups_config), 
                   map_int(groups_config, ~length(.x$subgroups %||% list()))),
    subgroup_id = unlist(map(groups_config, 
                             ~names(.x$subgroups %||% list()))),
    subgroup_label = unlist(map(groups_config, 
                                ~map_chr(.x$subgroups %||% list(), ~.x$label)))
  )
  
  list(
    group_labels = group_labels,
    subgroup_labels = subgroup_labels
  )
}


