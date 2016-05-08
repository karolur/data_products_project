library(shiny)
library(caret)
library(pROC)
library(ggplot2)
library(gridExtra)


shinyServer(
  function(input, output) {
    
    
    
    modelInput <- reactive({
      
      #getting data
      #dirname(sys.frame(1)$ofile)
      wd.datapath = paste0(getwd(),"/train_titanic.csv")
      wd.init = getwd() 
      dataset <- read.csv(wd.datapath)
      #str(dataset)
      #cleaning data
      dataset[dataset$Embarked == "", "Embarked"] <- "S"
      dataset$Embarked <- as.factor(as.character(dataset$Embarked))
      
      agetest<- dataset[!is.na(dataset$Age),
                        c("Pclass", "Sex", "Age", "SibSp", "Parch", "Fare", "Embarked")]
      agetest.train <- dataset[is.na(dataset$Age),
                               c("Pclass", "Sex", "Age", "SibSp", "Parch", "Fare", "Embarked")]
      agetest.test <- dataset[is.na(dataset$Age),
                              c("Pclass", "Sex", "Age", "SibSp", "Parch", "Fare", "Embarked")]
      agetest <- cbind(agetest[,c("Pclass", "Age", "SibSp", "Parch", "Fare")], 
                       model.matrix(~agetest$Sex -1)[,], 
                       model.matrix(~agetest$Embarked -1)[,])
      
      corr = cor(agetest)
      forsex = findCorrelation(corr)
      
      
      agetest.train <- dataset[!is.na(dataset$Age),
                               c("PassengerId", "Pclass", "Survived", "SibSp", "Age")]
      agetest.test <- dataset[is.na(dataset$Age),
                              c("PassengerId", "Pclass", "Survived", "SibSp")]
      lmPSS <-lm(Age~Pclass + Survived + SibSp, data = agetest.train)
      agetest.test$Age <- predict(lmPSS, newdata = agetest.test)
      dataset[dataset$PassengerId %in% agetest.test$PassengerId, "Age"] <- agetest.test$Age
      
      set.seed(666)
      inTraining <- createDataPartition(dataset$Survived, p=0.6, list=FALSE)
      trainset <- dataset[inTraining,]
      testset <- dataset[-inTraining,]
      
      # training
      model <- glm(Survived ~ Pclass + Sex +  Age + 
                     SibSp,
                   data = trainset,
                   family = binomial)
      
      trainset$prediction <- predict(model, type = "response")
      testset$prediction <- predict(model, newdata = testset, type = "response")
      
      # Build the ROC plot
      train.roc <- roc(trainset$Survived, 
                       predict(model, trainset, type = "response"))
      test.roc <- roc(testset$Survived, 
                      predict(model, testset, type = "response"))
      
      
      # Compute the sensitivity for 95, 99 % specificity
      
      
      mycoords <- coords(train.roc, x = "all")
      list(model, train.roc, test.roc, mycoords, trainset, testset)
      
      
    })

    
    output$newHist <- renderPlot({
        ths <- input$ths
      mod.output <- modelInput()
      model1 <- mod.output[[1]]
      train.roc <- mod.output[[2]]
      test.roc <- mod.output[[3]]
      mycoords <- mod.output[[4]]
      trainset <- mod.output[[5]]
      testset <- mod.output[[6]]
      
      
      prediction <- predict(model1, testset, type = "response") > ths
      prediction <- factor(ifelse(prediction == FALSE, "Did not Survive", "Survived"), 
                           levels = c("Did not Survive", "Survived"))
      testset$Survived1 <- factor(ifelse(testset$Survived == FALSE, "Did not Survive", "Survived"), 
                                  levels = c("Did not Survive", "Survived"))
      
      set_survived <- testset[testset$Survived1 == "Survived", ]
      set_survived$prediction <- predict(model1, set_survived, type = "response")
      set_notsurvived <- testset[testset$Survived1 == "Did not Survive", ]
      set_notsurvived$prediction <- predict(model1, set_notsurvived, type = "response")
      
      # Compute the density explicitly and plot using an area
      survived_dens <- density(set_survived$prediction)
      survived_dens <- data.frame(x = survived_dens$x,
                                  y = survived_dens$y)
      survived_dens <- survived_dens[survived_dens$x >= 0, ]
      
      # For the legitimate data
      notsurvived_dens <- density(set_notsurvived$prediction)
      notsurvived_dens <- data.frame(x = notsurvived_dens$x,
                                     y = notsurvived_dens$y)
      notsurvived_dens <- notsurvived_dens[notsurvived_dens$x >= 0, ]
      
      # And now plot
      plt1_survived <- ggplot(survived_dens[survived_dens$x < ths, ]) + 
        geom_area(aes(x = x, y = y), fill = "orange", color = "orange",
                  alpha = 0.4) +
        geom_area(data = survived_dens[survived_dens$x >= ths, ],
                  aes(x = x, y = y), fill = "darkred", color = "darkred",
                  alpha = 0.4) +
        geom_vline(xintercept = ths) +
        ggtitle("Distribution of people who Survived according to their LR score") +
        xlab("Logistic regression score (\"probability of having Survived\")") + 
        ylab("Density") +
        scale_x_continuous(limits = c(0, 1)) +
        scale_y_continuous(breaks = NULL)
      
      plt1_notsurvived <- ggplot(notsurvived_dens[notsurvived_dens$x < ths, ]) + 
        geom_area(aes(x = x, y = y), fill = "blue", color = "blue",
                  alpha = 0.4) +
        geom_area(data = notsurvived_dens[notsurvived_dens$x >= ths, ],
                  aes(x = x, y = y), fill = "purple", color = "purple",
                  alpha = 0.4) +
        geom_vline(xintercept = ths) +
        ggtitle("Distribution of non survivers joins according to their LR score") +
        xlab("Logistic regression score (\"probability of not surviving\")") + 
        ylab("Density") +
        scale_x_continuous(limits = c(0, 1)) +
        scale_y_continuous(breaks = NULL)
      
       spec <- 1 - mycoords[, min(which(mycoords[2, ] > ths))][2]
       sen <- mycoords[, min(which(mycoords[2, ] > ths))][3]
      
      ss <- data.frame (spec = spec, sen = sen)
      
      tr <- data.frame(x = 1 - train.roc$specificities, y = train.roc$sensitivities)
      
      tt <- data.frame(x = 1 - test.roc$specificities, y = test.roc$sensitivities )

      aucs <- data.frame(tr = train.roc$auc, tt = test.roc$auc)

      roc_plot <- ggplot() + 
        geom_line(data = tr, aes(x = x, y = y), 
                  size = 2, color = "blue") +
        geom_line(data = tt, aes(x = x, y = y), 
                  size = 2, alpha = 0.7, color = "red") +
        geom_abline(intercept = 0) +
        geom_point(data = ss, aes(spec,sen),colour="black", fill = "green", size = 6, shape = 21, stroke = 5) +
        labs(title =" ROC Curve", x = "1 - Specificity", y = "Sensitivity") +
        geom_text(data = aucs, aes(0.8, 0.2, label=paste("Train AUC: ", round(tr, digits = 4) )), 
                  colour = "blue") +
        geom_text(data = aucs, aes(0.8, 0.1, label=paste("Test AUC: ", round(tt, digits = 4) )), 
                  colour = "red")
      
      grid.arrange(roc_plot,  plt1_notsurvived, plt1_survived, nrow = 3)
    }, height = 600, width = 600)
  }
)