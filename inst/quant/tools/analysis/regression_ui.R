################################################################
# Regression - UI
################################################################
reg_show_interactions <- c("None" = "", "2-way" = 2, "3-way" = 3)
# reg_predict <- c("None" = "none", "Variable" = "vars", "Data" = "data","Command" = "cmd")
reg_predict <- c("None" = "none", "Data" = "data","Command" = "cmd")
reg_check <- c("Standardized coefficients" = "standardize",
               "Stepwise selection" = "stepwise")
reg_sum_check <- c("RMSE" = "rmse", "Sum of squares" = "sumsquares",
                   "VIF" = "vif", "Confidence intervals" = "confint")
reg_lines <- c("Line" = "line", "Loess" = "loess", "Jitter" = "jitter")
reg_plots <- c("None" = "", "Histograms" = "hist",
               "Correlations" = "correlations", "Scatter" = "scatter",
               "Dashboard" = "dashboard",
               "Residual vs explanatory" = "resid_pred",
               "Coefficient plot" = "coef",
               "Leverage plots" = "leverage")

reg_args <- as.list(formals(regression))

## list of function inputs selected by user
reg_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  reg_args$data_filter <- if (input$show_filter) input$data_filter else ""
  reg_args$dataset <- input$dataset
  for (i in r_drop(names(reg_args)))
    reg_args[[i]] <- input[[paste0("reg_",i)]]
  reg_args
})

reg_sum_args <- as.list(if (exists("summary.regression")) formals(summary.regression)
                        else formals(radiant:::summary.regression))

## list of function inputs selected by user
reg_sum_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(reg_sum_args))
    reg_sum_args[[i]] <- input[[paste0("reg_",i)]]
  reg_sum_args
})

reg_plot_args <- as.list(if (exists("plot.regression")) formals(plot.regression)
                         else formals(radiant:::plot.regression))

## list of function inputs selected by user
reg_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(reg_plot_args))
    reg_plot_args[[i]] <- input[[paste0("reg_",i)]]
  reg_plot_args
})

reg_pred_args <- as.list(if (exists("predict.regression")) formals(predict.regression)
                         else formals(radiant:::predict.regression))

## list of function inputs selected by user
reg_pred_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(reg_pred_args))
    reg_pred_args[[i]] <- input[[paste0("reg_",i)]]

  reg_pred_args$pred_cmd <- reg_pred_args$pred_data <- reg_pred_args$pred_vars <- ""
  if (input$reg_predict == "cmd")
    reg_pred_args$pred_cmd <- gsub("\\s", "", input$reg_pred_cmd) %>% gsub("\"","\'",.)
  else if (input$reg_predict == "data")
    reg_pred_args$pred_data <- input$reg_pred_data
  else if (input$reg_predict == "vars")
    reg_pred_args$pred_vars <- input$reg_pred_vars

    # reg_pred_args$pred_cmd <- gsub("\\s", "", input$reg_pred_cmd)

  reg_pred_args
})

reg_pred_plot_args <- as.list(if (exists("plot.reg_predict")) formals(plot.reg_predict)
                         else formals(radiant:::plot.reg_predict))

## list of function inputs selected by user
reg_pred_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(reg_pred_plot_args))
    reg_pred_plot_args[[i]] <- input[[paste0("reg_",i)]]
  reg_pred_plot_args
})

output$ui_reg_rvar <- renderUI({
  isNum <- "numeric" == .getclass() | "integer" == .getclass()
  vars <- varnames()[isNum]
  selectInput(inputId = "reg_rvar", label = "Response variable:", choices = vars,
    selected = state_single("reg_rvar",vars), multiple = FALSE)
})

output$ui_reg_evar <- renderUI({
  notChar <- "character" != .getclass()
  vars <- varnames()[notChar]
  if (not_available(input$reg_rvar)) vars <- character(0)
  if (length(vars) > 0 ) vars <- vars[-which(vars == input$reg_rvar)]

  ## if possible, keep current indep value when depvar changes
  ## after storing residuals or predictions
  isolate({
    init <- input$reg_evar %>%
      {if (!is_empty(.) && . %in% vars) . else character(0)}
    if (length(init) > 0) r_state$reg_evar <<- init
  })

  selectInput(inputId = "reg_evar", label = "Explanatory variables:", choices = vars,
    selected = state_multiple("reg_evar", vars, init),
    multiple = TRUE, size = min(10, length(vars)), selectize = FALSE)
})

output$ui_reg_pred_var <- renderUI({
  vars <- input$reg_evar
  selectInput("reg_pred_var", label = "Predict for variables:",
    choices = vars, selected = state_multiple("reg_pred_var", vars),
    multiple = TRUE, size = min(4, length(vars)), selectize = FALSE)
})

# adding interaction terms as needed
output$ui_reg_test_var <- renderUI({
  vars <- input$reg_evar
  if (!is.null(input$reg_int_var)) vars <- c(vars, input$reg_int_var)

  selectizeInput(inputId = "reg_test_var", label = "Variables to test:",
    choices = vars, selected = state_multiple("reg_test_var", vars, ""),
    multiple = TRUE,
    options = list(placeholder = 'None', plugins = list('remove_button'))
  )
})

output$ui_reg_show_interactions <- renderUI({
  if (length(input$reg_evar) == 2)
    choices <- reg_show_interactions[1:2]
  else if (length(input$reg_evar) > 2)
    choices <- reg_show_interactions
  else
    choices <- reg_show_interactions[1]

  radioButtons(inputId = "reg_show_interactions", label = "Interactions:",
               choices = choices,
               selected = state_init("reg_show_interactions"), inline = TRUE)
 })

output$ui_reg_int_var <- renderUI({
  if (is_empty(input$reg_show_interactions)) {
    choices <- character(0)
  } else {
    vars <- input$reg_evar
    if (not_available(vars) || length(vars) < 2) return()
    # vector of possible interaction terms to sel from glm_reg
    choices <- iterms(vars, input$reg_show_interactions)       # create list of interactions to show user
  }
  selectInput("reg_int_var", label = NULL, choices = choices,
    selected = state_multiple("reg_int_var", choices),
    multiple = TRUE, size = min(4,length(choices)), selectize = FALSE)
})

# X - variable
output$ui_reg_xvar <- renderUI({
  vars <- input$reg_evar
  selectizeInput(inputId = "reg_xvar", label = "X-variable:", choices = vars,
    selected = state_multiple("reg_xvar",vars),
    multiple = FALSE)
})

output$ui_reg_facet_row <- renderUI({
  vars <- input$reg_evar
  vars <- c("None" = ".", vars)
  selectizeInput("reg_facet_row", "Facet row", vars,
                 selected = state_single("reg_facet_row", vars, "."),
                 multiple = FALSE)
})

output$ui_reg_facet_col <- renderUI({
  vars <- input$reg_evar
  vars <- c("None" = ".", vars)
  selectizeInput("reg_facet_col", "Facet column", vars,
                 selected = state_single("reg_facet_col", vars, "."),
                 multiple = FALSE)
})

output$ui_reg_color <- renderUI({
  vars <- c("None" = "none", input$reg_evar)
  sel <- state_single("reg_color", vars, "none")
  selectizeInput("reg_color", "Color", vars, selected = sel,
                 multiple = FALSE)
})

## show error message from filter dialog
# output$ui_reg_pred_filt_err <- renderUI({
#   if (is_empty(r_data$reg_pred_filt_err)) return()
#   helpText(r_data$reg_pred_filt_err)
# })

# observeEvent(input$reg_pred_filt, {
#   selcom <- input$reg_pred_filt %>% gsub("\\n","", .) %>% gsub("\"","\'",.)
#   if (is_empty(selcom) || input$show_filter == FALSE) {
#     isolate(r_data$reg_pred_filt_err <- "")
#   } else if (grepl("([^=!<>])=([^=])",selcom)) {
#     isolate(r_data$reg_pred_filt_err <- "Invalid filter: never use = in a filter but == (e.g., year == 2014). Update or remove the expression")
#   } else {
#     seldat <- try(filter_(r_data[[input$dataset]], selcom), silent = TRUE)
#     if (is(seldat, 'try-error')) {
#       isolate(r_data$reg_pred_filt_err <- paste0("Invalid filter: \"", attr(seldat,"condition")$message,"\". Update or remove the expression"))
#     } else {
#       isolate(r_data$reg_pred_filt_err <- "")
#       # return(seldat)
#     }
#   }
# })

## data ui and tabs
output$ui_regression <- renderUI({
  tagList(
    conditionalPanel(condition = "input.tabs_regression == 'Predict'",
      wellPanel(
        selectInput("reg_predict", label = "Prediction input:", reg_predict,
          selected = state_single("reg_predict", reg_predict, "none")),
        conditionalPanel(condition = "input.reg_predict == 'vars'",
          uiOutput("ui_reg_pred_var")
        ),
        conditionalPanel("input.reg_predict == 'data'",
          selectizeInput(inputId = "reg_pred_data", label = "Predict for profiles:",
                      choices = c("None" = "",r_data$datasetlist),
                      selected = state_single("reg_pred_data", c("None" = "",r_data$datasetlist)), multiple = FALSE)
          # returnTextAreaInput("reg_pred_filt", label = "Prediction filter:", value = state_init("reg_pred_filt")),
          # uiOutput("ui_reg_pred_filt_err")
        ),
        conditionalPanel(condition = "input.reg_predict == 'cmd'",
          returnTextAreaInput("reg_pred_cmd", "Prediction command:",
            value = state_init("reg_pred_cmd", ""))
        ),
        conditionalPanel(condition = "input.reg_predict != 'none'",
          checkboxInput("reg_pred_plot", "Plot predictions", state_init("reg_pred_plot", FALSE)),
          conditionalPanel("input.reg_pred_plot == true",
            uiOutput("ui_reg_xvar"),
            uiOutput("ui_reg_facet_row"),
            uiOutput("ui_reg_facet_col"),
            uiOutput("ui_reg_color")
          )
        ),
        ## only show if full data is used for prediction
        conditionalPanel("input.reg_predict == 'data'",
                          # input.reg_pred_data == input.dataset",
          tags$table(
            tags$td(textInput("reg_store_pred_name", "Store predictions:", "predict_reg")),
            tags$td(actionButton("reg_store_pred", "Store"), style="padding-top:30px;")
          )
        )
      )
    ),
    conditionalPanel(condition = "input.tabs_regression == 'Plot'",
      wellPanel(
        selectInput("reg_plots", "Regression plots:", choices = reg_plots,
          selected = state_single("reg_plots", reg_plots)),
        conditionalPanel(condition = "input.reg_plots == 'coef'",
          checkboxInput("reg_intercept", "Include intercept", state_init("reg_intercept", FALSE))
        ),
        conditionalPanel(condition = "input.reg_plots == 'scatter' |
                                      input.reg_plots == 'dashboard' |
                                      input.reg_plots == 'resid_pred'",
          checkboxGroupInput("reg_lines", NULL, reg_lines,
            selected = state_init("reg_lines"), inline = TRUE)
        )
      )
    ),
    wellPanel(
      uiOutput("ui_reg_rvar"),
      uiOutput("ui_reg_evar"),

      conditionalPanel(condition = "input.reg_evar != null",

        uiOutput("ui_reg_show_interactions"),
        conditionalPanel(condition = "input.reg_show_interactions != ''",
          uiOutput("ui_reg_int_var")
        ),
        conditionalPanel(condition = "input.tabs_regression == 'Summary'",
          uiOutput("ui_reg_test_var"),
          checkboxGroupInput("reg_check", NULL, reg_check,
            selected = state_init("reg_check"), inline = TRUE),
          checkboxGroupInput("reg_sum_check", NULL, reg_sum_check,
            selected = state_init("reg_sum_check"), inline = TRUE)
        ),
        conditionalPanel(condition = "input.reg_predict == 'cmd' |
                         input.reg_predict == 'data' |
                         (input.reg_sum_check && input.reg_sum_check.indexOf('confint') >= 0) |
                         input.reg_plots == 'coef'",
             sliderInput("reg_conf_lev", "Confidence level:", min = 0.80,
                         max = 0.99, value = state_init("reg_conf_lev",.95),
                         step = 0.01)
        ),
        ## Only save residuals when filter is off
        conditionalPanel(condition = "input.tabs_regression == 'Summary' &
                                      (input.show_filter == false |
                                      input.data_filter == '')",
          tags$table(
            tags$td(textInput("reg_store_res_name", "Store residuals:", "residuals_reg")),
            tags$td(actionButton("reg_store_res", "Store"), style="padding-top:30px;")
          )
        )
      )
    ),
    help_and_report(modal_title = "Linear regression (OLS)",
                    fun_name = "regression",
                    help_file = inclRmd(file.path(r_path,"quant/tools/help/regression.Rmd")))
  )
})

reg_plot <- reactive({

  if (reg_available() != "available") return()
  if (is_empty(input$reg_plots)) return()

  # specifying plot heights
  plot_height <- 500
  plot_width <- 650
  nrVars <- length(input$reg_evar) + 1

  if (input$reg_plots == "hist") plot_height <- (plot_height / 2) * ceiling(nrVars / 2)
  if (input$reg_plots == "dashboard") plot_height <- 1.5 * plot_height
  if (input$reg_plots == "correlations") { plot_height <- 150 * nrVars; plot_width <- 150 * nrVars }
  if (input$reg_plots == "coef") plot_height <- 300 + 20 * length(.regression()$model$coefficients)
  if (input$reg_plots %in% c("scatter","leverage","resid_pred"))
    plot_height <- (plot_height/2) * ceiling((nrVars-1) / 2)

  list(plot_width = plot_width, plot_height = plot_height)
})

reg_plot_width <- function()
  reg_plot() %>% { if (is.list(.)) .$plot_width else 650 }

reg_plot_height <- function()
  reg_plot() %>% { if (is.list(.)) .$plot_height else 500 }

reg_pred_plot_height <- function()
  if (input$tabs_regression == "Predict" && is.null(r_data$reg_pred)) 0 else 500

# output is called from the main radiant ui.R
output$regression <- renderUI({

    register_print_output("summary_regression", ".summary_regression")
    register_print_output("predict_regression", ".predict_regression")
    register_plot_output("predict_plot_regression", ".predict_plot_regression",
                          height_fun = "reg_pred_plot_height")
    register_plot_output("plot_regression", ".plot_regression",
                         height_fun = "reg_plot_height",
                         width_fun = "reg_plot_width")

    # two separate tabs
    reg_output_panels <- tabsetPanel(
      id = "tabs_regression",
      tabPanel("Summary", verbatimTextOutput("summary_regression")),
      tabPanel("Predict",
        conditionalPanel("input.reg_pred_plot == true",
          plot_downloader("regression", height = reg_pred_plot_height(), po = "dlp_", pre = ".predict_plot_"),
          plotOutput("predict_plot_regression", width = "100%", height = "100%")
        ),
        downloadLink("dl_reg_pred", "", class = "fa fa-download alignright"), br(),
        verbatimTextOutput("predict_regression")
      ),
      tabPanel("Plot", plot_downloader("regression", height = reg_plot_height()),
        plotOutput("plot_regression", width = "100%", height = "100%"))
    )

    stat_tab_panel(menu = "Regression",
                  tool = "Linear (OLS)",
                  tool_ui = "ui_regression",
                  output_panels = reg_output_panels)
})

reg_available <- reactive({

  if (not_available(input$reg_rvar))
    return("This analysis requires a response variable of type integer\nor numeric and one or more explanatory variables.\nIf these variables are not available please select another dataset.\n\n" %>% suggest_data("diamonds"))

  if (not_available(input$reg_evar))
    return("Please select one or more explanatory variables.\n\n" %>% suggest_data("diamonds"))

  "available"
})

.regression <- reactive({
  do.call(regression, reg_inputs())
})

.summary_regression <- reactive({
  if (reg_available() != "available") return(reg_available())
  if (input$reg_rvar %in% input$reg_evar) return()
  do.call(summary, c(list(object = .regression()), reg_sum_inputs()))
})

.predict_regression <- reactive({
  r_data$reg_pred <- NULL
  if (reg_available() != "available") return(reg_available())
  if (is_empty(input$reg_predict)) return(invisible())
  r_data$reg_pred <- do.call(predict, c(list(object = .regression()), reg_pred_inputs()))
})

.predict_plot_regression <- reactive({
  if (!input$reg_pred_plot) return(" ")
  if (reg_available() != "available") return(reg_available())
  if (not_available(input$reg_xvar) || !input$reg_xvar %in% input$reg_evar) return(" ")
  if (is_empty(input$reg_predict) || is.null(r_data$reg_pred))
    return(invisible())
  do.call(plot, c(list(x = r_data$reg_pred), reg_pred_plot_inputs()))
})

.plot_regression <- reactive({
  if (reg_available() != "available") return(reg_available())
  if (is_empty(input$reg_plots))
    return("Please select a regression plot from the drop-down menu")

  if (input$reg_plots %in% c("correlations", "leverage"))
    capture_plot( do.call(plot, c(list(x = .regression()), reg_plot_inputs())) )
  else
    reg_plot_inputs() %>% { .$shiny <- TRUE; . } %>% { do.call(plot, c(list(x = .regression()), .)) }
})

observeEvent(input$regression_report, {
  isolate({
    outputs <- c("summary")
    inp_out <- list("","")
    inp_out[[1]] <- clean_args(reg_sum_inputs(), reg_sum_args[-1])
    figs <- FALSE
    if (!is_empty(input$reg_plots)) {
      inp_out[[2]] <- clean_args(reg_plot_inputs(), reg_plot_args[-1])
      outputs <- c(outputs, "plot")
      figs <- TRUE
    }
    xcmd <- ""
    # if (!is.null(r_data$reg_pred) && input$reg_predict != "none") {
    if (!is.null(r_data$reg_pred) && !is_empty(input$reg_predict, "none")) {
      inp_out[[2 + figs]] <- clean_args(reg_pred_inputs(), reg_pred_args[-1])
      outputs <- c(outputs, "result <- predict")
      dataset <- if (input$reg_predict == "data") input$reg_pred_data else input$dataset
      xcmd <-
        paste0("# store_reg(result, data = '", dataset, "', type = 'prediction', name = '", input$reg_store_pred_name,"')\n") %>%
        paste0("# write.csv(result, file = '~/reg_predictions.csv', row.names = FALSE)")
      # if (!is_empty(input$reg_xvar)) {
      if (input$reg_pred_plot) {
        inp_out[[3 + figs]] <- clean_args(reg_pred_plot_inputs(), reg_pred_plot_args[-1])
        outputs <- c(outputs, "plot")
        figs <- TRUE
      }
    }
    update_report(inp_main = clean_args(reg_inputs(), reg_args),
                  fun_name = "regression", inp_out = inp_out,
                  outputs = outputs, figs = figs,
                  fig.width = round(7 * reg_plot_width()/650,2),
                  fig.height = round(7 * reg_plot_height()/650,2),
                  xcmd = xcmd)
  })
})

observeEvent(input$reg_store_res, {
  isolate({
    robj <- .regression()
    if (!is.list(robj)) return()
    if (length(robj$model$residuals) != nrow(getdata(input$dataset, filt = "", na.rm = FALSE))) {
      return(message("The number of residuals is not equal to the number of rows in the data. If the data has missing values these will need to be removed."))
    }
    store_reg(robj, data = input$dataset, type = "residuals", name = input$reg_store_res_name)
  })
})

observeEvent(input$reg_store_pred, {
  isolate({
    pred <- r_data$reg_pred
    if (is.null(pred)) return()
    # if (nrow(pred) != nrow(getdata(input$dataset)))
    # print(nrow(pred))
    # print(nrow(getdata(input$reg_pred_data, filt = "", na.rm = FALSE)))
    if (nrow(pred) != nrow(getdata(input$reg_pred_data, filt = "", na.rm = FALSE)))
      return(message("The number of predicted values is not equal to the number of rows in the data. If the data has missing values these will need to be removed."))
    # store_reg(pred, data = input$dataset, type = "prediction", name = input$reg_store_pred_name)
    store_reg(pred, data = input$reg_pred_data, type = "prediction", name = input$reg_store_pred_name)
  })
})


output$dl_reg_pred <- downloadHandler(
  filename = function() { "reg_predictions.csv" },
  content = function(file) {
    do.call(predict, c(list(object = .regression()), reg_pred_inputs(),
            list(reg_save_pred = TRUE, prn = FALSE))) %>%
      write.csv(., file = file, row.names = FALSE)
  }
)
