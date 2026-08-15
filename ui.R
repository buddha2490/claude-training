# ui.R — Wu AI Harness

ui <- dashboardPage(
  skin = "black",

  # --- Header ----------------------------------------------------------------
  dashboardHeader(
    title     = "Wu AI Harness",
    titleWidth = 260
  ),

  # --- Sidebar ---------------------------------------------------------------
  dashboardSidebar(
    width = 260,
    sidebarMenu(
      id = "sidebar_tabs",
      menuItem("Home",    tabName = "home",       icon = icon("house")),
      menuItem("Domains", icon = icon("database"),
        menuSubItem("SDTM-Demographics", tabName = "dm_listing", icon = icon("users"))
      )
    )
  ),

  # --- Body ------------------------------------------------------------------
  dashboardBody(

    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
    ),

    tabItems(

      # -----------------------------------------------------------------------
      # HOME
      # -----------------------------------------------------------------------
      tabItem(tabName = "home",

        # KPI row
        fluidRow(
          valueBoxOutput("vb_subjects",  width = 3),
          valueBoxOutput("vb_sites",     width = 3),
          valueBoxOutput("vb_countries", width = 3),
          valueBoxOutput("vb_arms",      width = 3)
        ),

        # About + Getting Started
        fluidRow(
          box(
            title       = tagList(icon("circle-info"), " About This App"),
            status      = "primary",
            solidHeader = TRUE,
            width       = 8,

            tags$p(
              "The ", tags$strong("Wu AI Harness"), " is a Shiny application framework
              designed to support clinical programming workflows for CDISC submissions.
              This app serves as the training foundation for Wu Consulting's Claude Code
              pilot program."
            ),
            tags$p(
              "Participants will use ", tags$strong("Claude Code"),
              " — Anthropic's AI-powered command-line tool — to extend this application
              by adding SDTM and ADaM domain listings, visualizations, and summary
              statistics tables."
            ),

            tags$hr(),
            tags$h5(icon("bullseye"), " Training Objectives"),
            tags$ul(
              tags$li("Navigate and understand a production-style Shiny codebase"),
              tags$li("Use Claude Code to generate, modify, and debug R/Shiny code"),
              tags$li("Add new CDISC domain listings and interactive features"),
              tags$li("Learn the Wu AI Harness architecture and project conventions")
            ),

            tags$hr(),
            tags$h5(icon("database"), " Study WU-001 — Simulated Clinical Trial"),
            tags$table(
              class = "table table-bordered table-condensed study-table",
              tags$thead(tags$tr(
                tags$th("Study ID"), tags$th("Design"),
                tags$th("Enrollment"),  tags$th("Duration")
              )),
              tags$tbody(tags$tr(
                tags$td("WU-001"),
                tags$td("Randomized, double-blind, placebo-controlled"),
                tags$td("Jan 2022 – Jun 2023"),
                tags$td("12 – 52 weeks")
              ))
            )
          ),

          box(
            title       = tagList(icon("laptop-code"), " Getting Started"),
            status      = "info",
            solidHeader = TRUE,
            width       = 4,

            tags$h5(icon("circle-check"), " Prerequisites"),
            tags$ul(
              tags$li(tags$a("Positron IDE", href = "https://positron.posit.co/download.html", target = "_blank")),
              tags$li("Claude Code ", tags$code("npm install -g @anthropic-ai/claude-code")),
              tags$li("R 4.x with renv")
            ),

            tags$hr(),
            tags$h5(icon("play"), " Setup"),
            tags$ol(
              tags$li("Clone the repository from GitHub"),
              tags$li(tags$span("Run ", tags$code('source("setup.R")'), " in Positron")),
              tags$li("Launch Claude Code from the terminal: ", tags$code("claude")),
              tags$li("Explore the ", tags$strong("Domains"), " menu to the left")
            ),

            tags$hr(),
            tags$div(
              class = "text-center text-muted",
              style = "font-size: 0.85em;",
              icon("lightbulb"), " ",
              tags$em("Ask Claude Code to add a new domain listing to get started.")
            )
          )
        )
      ),

      # -----------------------------------------------------------------------
      # SDTM DEMOGRAPHICS
      # -----------------------------------------------------------------------
      tabItem(tabName = "dm_listing",

        fluidRow(
          box(
            title       = tagList(icon("users"), " SDTM Demographics (DM)"),
            status      = "primary",
            solidHeader = TRUE,
            width       = 12,
            DTOutput("tbl_dm")
          )
        )
      )
    )
  )
)
