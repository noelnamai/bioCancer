output$MutDataTable <- DT::renderDataTable({
  ## check if GenProf is mutation

  if (length(grep("mutation", input$GenProfID))==0){

    dat <- as.data.frame("Please select mutations from Genetic Profiles")
  }else{

    #dat <-

    if(input$GeneListID == "Genes"){
      GeneList <- r_data$Genes
    }else if(input$GeneListID == "Reactome_GeneList"){
      GeneList <- t(r_data$Reactome_GeneList)
    }else{
      GeneList <- as.character(t(unique(read.table(paste0(getwd(),"/data/GeneList/",input$GeneListID,".txt" ,sep="")))))
    }
    ##### Get Mutation Data for selected Case and Genetic Profile
    if(length(GeneList)>500){
      dat <- getMegaProfData(GeneList,input$GenProfID,input$CasesID, Class="MutData")
    } else{
      if (inherits(try(dat <- getMutationData(cgds,input$CasesID, input$GenProfID, GeneList), silent=FALSE),"try-error")){
        msgbadGeneList <- "There are some Gene Symbols not supported by cbioportal server"
        tkmessageBox(message=msgbadGeneList, icon="warning")
      }else{
        dat <- getMutationData(cgds,input$CasesID, input$GenProfID, GeneList)
      }



      ## change rownames in the first column
      dat <- as.data.frame(dat %>% add_rownames("Patients"))
      dat <- dat[input$ui_Mut_vars]

      #   if(is.numeric(dat[1,1])){
      #     dat <- round(dat, digits = 3)
    }
    ####
    r_data[['MutData']] <- dat
    # action = DT::dataTableAjax(session, dat, rownames = FALSE, toJSONfun = my_dataTablesJSON)
    action = DT::dataTableAjax(session, dat, rownames = FALSE)

    #DT::datatable(dat, filter = "top", rownames = FALSE, server = TRUE,
    DT::datatable(dat, filter = list(position = "top", clear = FALSE, plain = TRUE),
                  rownames = FALSE, style = "bootstrap", escape = FALSE,
                  # class = "compact",
                  options = list(
                    ajax = list(url = action),
                    search = list(regex = TRUE),
                    columnDefs = list(list(className = 'dt-center', targets = "_all")),
                    autoWidth = TRUE,
                    processing = FALSE,
                    pageLength = 10,
                    lengthMenu = list(c(10, 25, 50, -1), c('10','25','50','All'))
                  )
    )
  }
})


output$dl_MutData_tab <- shiny::downloadHandler(
  filename = function() { paste0("MutData_tab.csv") },
  content = function(file) {
    data_filter <- if (input$show_filter) input$data_filter else ""
    getdata(r_data$MutData, vars = input$ui_Mut_vars, filt = data_filter,
            rows = NULL, na.rm = FALSE) %>%
      write.csv(file, row.names = FALSE)
  }
)