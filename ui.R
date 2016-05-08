library(shiny)
shinyUI(
  navbarPage("Titanic Data", 
     # multi-page user-interface that includes a navigation bar.
     tabPanel("Logistic Regression ROC",
              sidebarPanel(
                          sliderInput('ths', 'Thresholds',value = 0.5, 
                                      min = 0.5, max = 1, step = 0.05,)
                           ), 
              mainPanel(plotOutput('newHist'))
              ),
     tabPanel("About",
              mainPanel(
                includeMarkdown("about.Rmd")
              )
     ) # end of "About" tab panel
            )
      )