#' Get fbref Team's Player Season Statistics
#'
#' Returns the team's players season stats for a selected team(s) and stat type
#'
#' @param team_urls the URL(s) of the teams(s) (can come from fb_teams_urls())
#' @param stat_type the type of statistic required
#'
#'The statistic type options (stat_type) include:
#'
#' \emph{"standard"}, \emph{"shooting"}, \emph{"passing"},
#' \emph{"passing_types"}, \emph{"gca"}, \emph{"defense"}, \emph{"possession"}
#' \emph{"playing_time"}, \emph{"misc"}, \emph{"keeper"}, \emph{"keeper_adv"}
#'
#' @return returns a dataframe of all players of a team's season stats
#'
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#'
#' @export
#'
#' @examples
#' \dontrun{
#' fb_team_player_stats("https://fbref.com/en/squads/d6a369a2/Fleetwood-Town-Stats",
#'                        stat_type = 'standard')
#'
#' league_url <- fb_league_urls(country = "ENG", gender = "M",
#'                                              season_end_year = 2022, tier = "3rd")
#' team_urls <- fb_teams_urls(league_url)
#' multiple_playing_time <- fb_team_player_stats(team_urls,
#'                          stat_type = "playing_time")
#' }

fb_team_player_stats <- function(team_urls, stat_type) {

  stat_types <- c("standard", "shooting", "passing", "passing_types", "gca", "defense", "possession", "playing_time", "misc", "keeper", "keeper_adv")

  if(!stat_type %in% stat_types) stop("check stat type")

  # .pkg_message("Scraping {team_or_player} season '{stat_type}' stats")

  main_url <- "https://fbref.com"

  get_each_team_players <- function(team_url) {

    pb$tick()

    page <- xml2::read_html(team_url)

    team_season <- page %>% rvest::html_nodes("h1") %>% rvest::html_nodes("span") %>% .[1] %>% rvest::html_text()
    season <- team_season %>% stringr::str_extract(., "(\\d+)-(\\d+)")
    Squad <- team_season %>% gsub("(\\d+)-(\\d+)", "", .) %>% gsub("\\sStats", "", .) %>% stringr::str_squish()
    league <- page %>% rvest::html_nodes("h1") %>% rvest::html_nodes("span") %>% .[2] %>% rvest::html_text() %>% gsub("\\(", "", .) %>% gsub("\\)", "", .)

    tabs <- page %>% rvest::html_nodes(".table_container")
    tab_names <- page %>% rvest::html_nodes("#content") %>% rvest::html_nodes(".table_wrapper") %>% rvest::html_attr("id")

    tab_idx <- grep(paste0("all_stats_", stat_type, "$"), tab_names)

    if(length(tab_idx) == 0) {
      stop(glue::glue("Stat: {stat_type} not available for {Squad}"))
      tab <- data.frame()
    } else {
      tab <- tabs[tab_idx] %>% rvest::html_node("table") %>% rvest::html_table() %>% data.frame()

      var_names <- tab[1,] %>% as.character()
      new_names <- paste(var_names, names(tab), sep = "_")

      new_names <- new_names %>%
        gsub("\\..[0-9]", "", .) %>%
        gsub("\\.[0-9]", "", .) %>%
        gsub("\\.", "_", .) %>%
        gsub("_Var", "", .) %>%
        gsub("#", "Player_Num", .) %>%
        gsub("%", "_percent", .) %>%
        gsub("_Performance", "", .) %>%
        gsub("_Penalty", "", .) %>%
        gsub("1/3", "Final_Third", .) %>%
        gsub("\\+/-", "Plus_Minus", .) %>%
        gsub("/", "_per_", .) %>%
        gsub("-", "_minus_", .) %>%
        gsub("90s", "Mins_Per_90", .) %>%
        gsub("__", "_", .)

      names(tab) <- new_names
      tab <- tab[-1,]

      remove_rows <- min(grep("Squad ", tab$Player)):nrow(tab)
      tab <- tab[-remove_rows, ]
      tab$Matches <- NULL

      if(any(grepl("Nation", colnames(tab)))) {
        tab$Nation <- gsub(".*? ", "", tab$Nation)
      }

      non_num_vars <- c("Player", "Nation", "Pos", "Age")
      cols_to_transform <- names(tab)[!names(tab) %in% non_num_vars]

      tab <- tab %>%
        dplyr::mutate_at(.vars = cols_to_transform, .funs = function(x) {gsub(",", "", x)}) %>%
        dplyr::mutate_at(.vars = cols_to_transform, .funs = function(x) {gsub("+", "", x)}) %>%
        dplyr::mutate_at(.vars = cols_to_transform, .funs = as.numeric)

      player_urls <- tabs[tab_idx] %>% rvest::html_node("table") %>% rvest::html_nodes("tbody") %>%
        rvest::html_nodes("th a") %>% rvest::html_attr("href") %>%
        paste0(main_url, .)


      tab <- tab %>%
        dplyr::mutate(Season = season,
                      Squad=Squad,
                      Comp=league,
                      PlayerURL = player_urls) %>%
        dplyr::select(.data$Season, .data$Squad, .data$Comp, dplyr::everything())
    }

    return(tab)

  }

  # create the progress bar with a progress function.
  pb <- progress::progress_bar$new(total = length(team_urls))

  all_stats_df <- team_urls %>%
    purrr::map_df(get_each_team_players)

  return(all_stats_df)

}
