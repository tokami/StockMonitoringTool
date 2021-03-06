library(TropFishR)

run_elefan_ga <- function(
  x,
  binSize = NULL,
  #binSize = 4,
  seasonalised = FALSE,
  low_par = NULL,
  up_par = NULL,
  popSize = 50,
  maxiter = 100,
  run = maxiter,
  parallel = FALSE,
  pmutation = 0.1,
  pcrossover = 0.8,
  elitism = base::max(1, round(popSize*0.05)),
  MA = 5,
  addl.sqrt = FALSE,
  agemax = NULL,
  flagging.out = TRUE,
  seed = 1,
  plot = FALSE,
  plot.score = TRUE,
  plus_group = 0,
  ...
) {
  set.seed(1)
  pdf(NULL)
  
  returnResults <- list()
  out <- tryCatch( {
    print(paste0("TropFishR version:", packageVersion("TropFishR")))
    
    # adjust bin size
    
    smt_lfqa <- lfqModify(lfqRestructure(x), bin_size = binSize)
    
    # plot raw and restructured LFQ data
    
    lfqbin <- lfqRestructure(smt_lfqa, MA = MA, addl.sqrt = addl.sqrt)

    opar <- par(mfrow = c(2,1), mar = c(2,5,2,3), oma = c(2,0,0,0))
    
    
    returnResults[['plot1']] <- lfqbin
    #plot(lfqbin, Fname = "catch", date.axis = "modern")
    
    returnResults[['plot2']] <- lfqbin
    #plot(lfqbin, Fname = "rcounts", date.axis = "modern")
    
    #par(opar)
    
    
    
    # run ELEFAN with genetic algorithm
    res_GA <- ELEFAN_GA(smt_lfqa, MA = MA, seasonalised = seasonalised, maxiter = maxiter, addl.sqrt = addl.sqrt,low_par=low_par,up_par=up_par,monitor=FALSE)
    
    #  res_GA <- ELEFAN_GA(smt_lfqa, MA = 5, seasonalised = TRUE, maxiter = 10, addl.sqrt = TRUE,
    #                      
    #                      low_par = list(Linf = 119, K = 0.01, t_anchor = 0, C = 0, ts = 0),
    #                      
    #                      up_par = list(Linf = 129, K = 1, t_anchor = 1, C = 1, ts = 1),
    #                      
    #                      monitor = FALSE)
    returnResults[['data']] <- res_GA

    # show results
    
    res_GA$par; res_GA$Rn_max
    
    
    
    # plot LFQ and growth curves
    
    #plot(lfqbin, Fname = "rcounts",date.axis = "modern", ylim=c(0,130))
    
    lt <- lfqFitCurves(smt_lfqa, par = list(Linf=123, K=0.2, t_anchor=0.25, C=0.3, ts=0),
                       
                       draw = TRUE, col = "grey", lty = 1, lwd=1.5)
    
    # lt <- lfqFitCurves(smt_lfq, par = res_RSA$par,
    
    #                    draw = TRUE, col = "goldenrod1", lty = 1, lwd=1.5)
    
    lt <- lfqFitCurves(smt_lfqa, par = res_GA$par,
                       
                       draw = TRUE, col = "blue", lty = 1, lwd=1.5)
    
    lt <- lfqFitCurves(smt_lfqa, par = res_GA$par,
                       
                       draw = TRUE, col = "lightblue", lty = 1, lwd=1.5)
    
    # assign estimates to the data list
    
    smt_lfqa <- c(smt_lfqa, res_GA$par)
    
    
    
    
    
    ##########################
    
    # Natural mortality
    
    ##########################
    
    
    
    
    
    # estimation of M
    
    Ms <- M_empirical(Linf = res_GA$par$Linf, K_l = res_GA$par$K, method = "Then_growth")
    
    smt_lfqa$M <- as.numeric(Ms)
    
    # show results
    
    paste("M =", as.numeric(Ms))
    
    #> [1] "M = 0.217"
    
    # summarise catch matrix into vector
    smt_lfqb <- lfqModify(lfqRestructure(smt_lfqa), vectorise_catch = TRUE)
    # assign estimates to the data list
    catch_columns <- NA
    
    if (length(smt_lfqb$dates) > 1) {
      catch_columns <- length(smt_lfqb$dates) - 1
    }
    
    if (!exists("smt_lfqb$C")) {
      smt_lfqb$C <- 0
    }
    if (!exists("smt_lfqb$ts")) {
      smt_lfqb$ts <- 0
    }
    
    res_cc <- catchCurve(smt_lfqb, reg_int = NULL, calc_ogive = TRUE, catch_columns = catch_columns, plot=FALSE, auto = TRUE)
    #res_cc <- catchCurve(smt_lfqb)
    smt_lfqb$Z <- res_cc$Z
    #############smt_lfqb$Z <- 0.4
    
    smt_lfqb$FM <- as.numeric(smt_lfqb$Z - smt_lfqb$M)
    
    smt_lfqb$E <- smt_lfqb$FM/smt_lfqb$Z
    
    #> [1] "Z = 0.4"
    
    #> [1] "FM = 0.18"
    
    #> [1] "E = 0.46"
    
    #> [1] "L50 = 34.46"
    
    #Stock size and status
    
    # add plus group which is smaller than Linf
    calculated_plus_group <- plus_group
    if (plus_group == 0) {
      calculated_plus_group <- max(smt_lfqb$midLengths)
      for (x in smt_lfqb$midLengths) {
        if ((max(smt_lfqb$midLengths) / 2) < x) {
          calculated_plus_group <- x
          break
        }
      }
    }
    smt_lfqc <- lfqModify(smt_lfqb, plus_group = calculated_plus_group)
    # assign length-weight parameters to the data list
    
    smt_lfqc$a <- 0.015
    
    smt_lfqc$b <- 3
    
    # run CA
    catch_columns <- NA
    if (length(smt_lfqc$dates) > 1) {
      catch_columns <- length(smt_lfqc$dates) - 1
    }
    vpa_res <- VPA(param = smt_lfqc, terminalF = smt_lfqc$FM,
                   
                   analysis_type = "CA",
                   
                   plot=TRUE, catch_corFac = (1+4/12), catch_columns = catch_columns)
    
    # stock size
    
    sum(vpa_res$annualMeanNr, na.rm =TRUE) / 1e3
    
    #> [1] 372.3072
    
    # stock biomass
    
    sum(vpa_res$meanBiomassTon, na.rm = TRUE)
    
    #> [1] 986289.5
    
    # assign F per length class to the data list
    
    smt_lfqc$FM <- vpa_res$FM_calc
    
    
    
    #Yield per recruit modelling
    
    # Thompson and Bell model with changes in F
    
    TB1 <- predict_mod(smt_lfqc, type = "ThompBell",
                       
                       FM_change = seq(0,1.5,0.05),  stock_size_1 = 1,
                       
                       curr.E = smt_lfqc$E, plot = FALSE, hide.progressbar = TRUE)
    
    
    
    # Thompson and Bell model with changes in F and Lc
    
    TB2 <- predict_mod(smt_lfqc, type = "ThompBell",
                       
                       FM_change = seq(0,1.5,0.1), Lc_change = seq(25,50,0.1),
                       
                       stock_size_1 = 1,
                       
                       curr.E = smt_lfqc$E, curr.Lc = res_cc$L50,
                       
                       s_list = list(selecType = "trawl_ogive",
                                     
                                     L50 = res_cc$L50, L75 = res_cc$L75),
                       
                       plot = FALSE, hide.progressbar = TRUE)
    
    # plot results
    
    par(mfrow = c(2,1), mar = c(4,5,2,4.5), oma = c(1,0,0,0))
    
    returnResults[['plot3']] <- TB1
    #plot(TB1, mark = TRUE)
    #mtext("(a)", side = 3, at = -1, line = 0.6)
    
    returnResults[['plot4']] <- TB2
    #plot(TB2, type = "Isopleth", xaxis1 = "FM", mark = TRUE, contour = 6)
    #mtext("(b)", side = 3, at = -0.1, line = 0.6)
    
    # Biological reference levels
    
    
    
    TB1$df_Es
    
    #>   Fmsy F05      Emsy       E05
    
    #> 1 0.25 0.1 0.5353319 0.3154574
    
    # Current yield and biomass levels
    
    TB1$currents
  },
  error=function(cond) {
    print("There was an error here")
    message(paste0("Error!!", cond))
    errorResult = list()
    errorResult[['error']] <- gettext(cond)
    return (errorResult)
    # Choose a return value in case of error
  },
  finally={
    print("Done")
  }) 
  if ('error' %in% names(out)) {
    returnResults[['error']] <- out$error
  }
  return (returnResults)
  
}
