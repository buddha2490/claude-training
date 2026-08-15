# server.R — Wu AI Harness

server <- function(input, output, session) {

  # --- Home: value boxes -----------------------------------------------------

  output$vb_subjects <- renderValueBox({
    valueBox(
      value    = formatC(N_SUBJECTS, format = "d", big.mark = ","),
      subtitle = "Total Subjects",
      icon     = icon("users"),
      color    = "aqua"
    )
  })

  output$vb_sites <- renderValueBox({
    valueBox(
      value    = N_SITES,
      subtitle = "Study Sites",
      icon     = icon("hospital"),
      color    = "blue"
    )
  })

  output$vb_countries <- renderValueBox({
    valueBox(
      value    = N_COUNTRIES,
      subtitle = "Countries",
      icon     = icon("globe"),
      color    = "light-blue"
    )
  })

  output$vb_arms <- renderValueBox({
    valueBox(
      value    = N_ARMS,
      subtitle = "Treatment Arms",
      icon     = icon("flask"),
      color    = "teal"
    )
  })

  # --- DM listing ------------------------------------------------------------
  # server = FALSE: 1,000 rows is small enough to send to browser, and allows
  # CSV/Excel Buttons to export all filtered rows (not just the current page).

  output$tbl_dm <- renderDT({
    datatable(
      dm,
      rownames   = FALSE,
      selection  = "none",
      filter     = "top",
      extensions = c("Buttons", "FixedHeader"),
      options    = list(
        pageLength  = 25,
        lengthMenu  = list(c(10, 25, 50, 100, -1), c("10", "25", "50", "100", "All")),
        dom         = "lBfrtip",
        buttons     = list(
          list(extend = "colvis", text = "Columns"),
          list(extend = "csv",   text = "CSV"),
          list(extend = "excel", text = "Excel")
        ),
        scrollX     = TRUE,
        fixedHeader = TRUE,
        # Hide redundant / secondary columns by default (0-based column indices).
        # Users can restore them via the Columns button.
        # Hidden: STUDYID(0), DOMAIN(1), SUBJID(3), RFXSTDTC(6), RFXENDTC(7),
        #         RFICDTC(8), RFPENDTC(9), DTHDTC(10), AGEU(14),
        #         ARM(19), ACTARMCD(20), ACTARM(21), DMDTC(23), DMDY(24)
        columnDefs  = list(
          list(visible = FALSE,
               targets = c(0, 1, 3, 6, 7, 8, 9, 10, 14, 19, 20, 21, 23, 24))
        )
      )
    )
  }, server = FALSE)

}
