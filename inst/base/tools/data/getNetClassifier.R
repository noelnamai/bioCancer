getGenesClassifier <- reactive({

  shiny::withProgress(message = 'geNetClassifier is running...', value = 0.1, {
    Sys.sleep(0.25)

    checked_Studies <- input$StudiesIDClassifier

    GeneList <- whichGeneList(input$GeneListID)

    SamplesSize <- input$SampleSizeClassifierID
    Threshold <- input$ClassifierThresholdID

    SamplingProfsData <- 0
    DiseasesType <- 0
    for (s in 1:length(checked_Studies)){

      GenProf <- input$GenProfsIDClassifier[s]
      Case <- input$CasesIDClassifier[s]

      if(length(GeneList)>500){
        ProfData <- getMegaProfData(GeneList,GenProf,Case, Class="ProfData" )
      } else{
        ProfData<- getProfileData(cgds,GeneList, GenProf,Case)
      }

      ProfData <- t(ProfData)
      ##remove all NAs rows
      if (inherits(try(ProfData<- ProfData[which(apply( !( apply(ProfData,1,is.na) ),2,sum)!=0 ),] , silent=FALSE),"try-error"))
      {
        stop("Reselect Cases and Genetic Profiles from Samples. It is recommanded to use v2_mrna data. ")
      } else{
        ProfData<- ProfData[which( apply( !( apply(ProfData,1,is.na) ),2,sum)!=0 ),]

      }
      if(ncol(ProfData) < input$SampleSizeClassifierID){
        msgBigSampl <- paste(checked_Studies[s], "has only", ncol(ProfData),"samples.","\nSelect at Max: ",ncol(ProfData), "samples")
         shiny::withProgress(message= msgBigSampl, value = 0.1,
                     {p1 <- proc.time()
                     Sys.sleep(2) # wait 2 seconds
                     proc.time() - p1 })

        stop(msgBigSampl)
      }
      set.seed(1234)
      SamplingProfData <- t(apply(ProfData, 1,function(x)sample(x[!is.na(x)],input$SampleSizeClassifierID)))

      SamplingColnamesProfData <- sample(colnames(ProfData), input$SampleSizeClassifierID)

      colnames(SamplingProfData) <- SamplingColnamesProfData
      SamplingProfsData <- cbind.na(SamplingProfsData,SamplingProfData)
      print(paste("Sampling from ",Case))
      ##Extracting Disease Type
      DiseaseType  <- as.matrix(rep(checked_Studies[s],times=input$SampleSizeClassifierID))
      DiseasesType <- c(DiseasesType, DiseaseType)

    }
    SamplingProfsData<- SamplingProfsData[,-1]
    DiseasesType <-DiseasesType[-1]
    DiseasesType <- as.data.frame(DiseasesType)
    print("converting DiseaseType as DataFrame...")

    if (inherits(try(rownames(DiseasesType) <- colnames(SamplingProfsData) , silent=FALSE),"try-error"))
    {
      msgDuplicateSamples <- paste("Duplicate sample names are not allowed. Do no select two studies from the same disease.")
      shiny::withProgress(message= msgDuplicateSamples, value = 0.1,
                   {p1 <- proc.time()
                   Sys.sleep(2) # wait 2 seconds
                   proc.time() - p1 })
      stop(msgDuplicateSamples)
    } else{
      print(paste("SamplingProfsData:", dim(SamplingProfsData)))
      print(paste("DiseasesType:", dim(DiseasesType)))
      rownames(DiseasesType) <- colnames(SamplingProfsData)
    }


    print("adding rownames to DiseasesType...")
    ## create labelDescription for columns of phenoData.
    ## labeldescription is used by Biobase packages
    ## In our case labelDescription is Equal to column names
    ## Bioconductor’s Biobase package provides a class called AnnotatedDataFrame
    metaData <- data.frame(labelDescription= "DiseasesType", row.names="DiseasesType")

    print("getting metaData...")
    ##that conveniently stores and manipulates
    ##the phenotypic data and its metadata in a coordinated fashion.
    phenoData<-new("AnnotatedDataFrame", data=DiseasesType, varMetadata=metaData)
    print("getting phenoData...")
    ##Assembling an ExpressionSet


    eSetClassifier <- Biobase::ExpressionSet(assayData=SamplingProfsData, phenoData=phenoData, annotation="GO")
    print("getting eSetClassifier...")
    if(min(Biobase::exprs(eSetClassifier), na.rm=TRUE)<0){
      print("There are negative values. Translating values by adding the absolute of minimum value to all matrix")
      Biobase::exprs(eSetClassifier) <- Biobase::exprs(eSetClassifier)+(abs(min(Biobase::exprs(eSetClassifier), na.rm=TRUE)))
    }

    if (inherits(try(signGenesRank_DiseaseType<- geNetClassifier::calculateGenesRanking(eSetClassifier[,1:(input$SampleSizeClassifierID*length(checked_Studies))], sampleLabels="DiseasesType", lpThreshold= input$ClassifierThresholdID, returnRanking="significant", plotLp = FALSE), silent=TRUE),"try-error"))
    {
      msgNoSignificantDiff <- paste("The current genes don't differentiate the classes (Cancers)..")

      shiny::withProgress(message= msgNoSignificantDiff, value = 0.1,
                   {p1 <- proc.time()
                   Sys.sleep(2) # wait 2 seconds
                   proc.time() - p1 })

      stop(msgNoSignificantDiff )
    } else{

      signGenesRank_DiseaseType <- geNetClassifier::calculateGenesRanking(eSetClassifier[,1:(input$SampleSizeClassifierID*length(checked_Studies))], sampleLabels="DiseasesType", lpThreshold= input$ClassifierThresholdID, returnRanking="significant", plotLp = FALSE)
    }

    ## this line display the rank of postprob of all genes
    #apply(-signGenesRank_DiseaseType@postProb[,-1,drop=FALSE],2,rank, ties.method="random")

    GenesClassDetails <- geNetClassifier::genesDetails(signGenesRank_DiseaseType)
    r_data[['GenesClassDetailsForPlots']] <- GenesClassDetails
    #GenesClassDetails_bkp1 <<- GenesClassDetails

    print("getting Genes Details...")
    GenesClassDetails_ls <- lapply(GenesClassDetails, function(x) x %>% add_rownames("Genes"))
    GenesClassDetails_df <- plyr::ldply(GenesClassDetails_ls)
    r_data[['GenesClassDetails']] <- GenesClassDetails_df[,-1]

    #GenesClassTab <- do.call(rbind.data.frame, GenesClassDetails)
    #GenesClassTab <- t(t(as.data.frame.matrix(GenesClassTab)))

    return(GenesClassDetails_df[,-1])
  })
})


output$getGenesClassifier <- DT::renderDataTable({
  dat <-   getGenesClassifier()
  displayTable(dat)
})


output$dl_GenesClassDetails_tab <- shiny::downloadHandler(
  filename = function() { paste0("MutData_tab.csv") },
  content = function(file) {
    data_filter <- if (input$show_filter) input$data_filter else ""
    getdata(r_data$GenesClassDetails, vars = input$ui_Mut_vars, filt = data_filter,
            rows = NULL, na.rm = FALSE) %>%
      write.csv(file, row.names = FALSE)
  }
)
