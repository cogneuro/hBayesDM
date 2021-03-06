#' Choice Reaction Time task, drift diffusion modeling
#' 
#' @description 
#' Hierarchical Bayesian Modeling of choice/reaction time data with the following parameters: "alpha" (boundary separation), "beta" (bias), "delta" (drift rate), "tau" (non-decision time). 
#' The code is based on codes/comments by Guido Biele, Joseph Burling, Andrew Ellis, and potentially others @ Stan mailing 
#' 
#' \strong{MODEL:}
#' Ratcliff drift diffusion model - multiple subjects. Note that this implementation is \strong{not} the full drift diffusion model as described in 
#' Ratcliff (1978). This implementation estimates the drift rate, boundary separation, starting point, and non-decision time, but not the between- 
#' and within-trial variances in these parameters. 
#' 
#' @param data A .txt file containing the data to be modeled. Data columns should be labelled as follows: "subjID, ""choice", and "RT". See \bold{Details} below for more information.
#' @param niter Number of iterations, including warm-up.
#' @param nwarmup Number of iterations used for warm-up only.
#' @param nchain Number of chains to be run.
#' @param ncore Integer value specifying how many CPUs to run the MCMC sampling on. Defaults to 1. 
#' @param nthin Every \code{i == nthin} sample will be used to generate the posterior distribution. Defaults to 1. A higher number can be used when auto-correlation within the MCMC sampling is high. 
#' @param inits Character value specifying how the initial values should be generated. Options are "fixed" or "random" or your own initial values.
#' @param indPars Character value specifying how to summarize individual parameters. Current options are: "mean", "median", or "mode".
#' @param saveDir Path to directory where .RData file of model output (\code{modelData}) can be saved. Leave blank if not interested.
#' @param email Character value containing email address to send notification of completion. Leave blank if not interested. 
#' @param RTbound A floating point number representing the lower bound (i.e. minimum allowed) reaction time. Defaults to 0.1 (100 milliseconds).
#' @param modelRegressor Exporting model-based regressors? TRUE or FALSE. Currently not available for this model.
#' @param adapt_delta Floating point number representing the target acceptance probability of a new sample in the MCMC chain. Must be between 0 and 1. See \bold{Details} below.
#' @param stepsize Integer value specifying the size of each leapfrog step that the MCMC sampler can take on each new iteration. See \bold{Details} below.
#' @param max_treedepth Integer value specifying how many leapfrog steps that the MCMC sampler can take on each new iteration. See \bold{Details} below.
#' 
#' @return \code{modelData}  A class \code{'hBayesDM'} object with the following components:
#' \describe{
#'  \item{\code{model}}{Character string with the name of the model (\code{"choiceRT_ddm"}).}
#'  \item{\code{allIndPars}}{\code{'data.frame'} containing the summarized parameter 
#'    values (as specified by \code{'indPars'}) for each subject.}
#'  \item{\code{parVals}}{A \code{'list'} where each element contains posterior samples
#'    over different model parameters. }
#'  \item{\code{fit}}{A class \code{'stanfit'} object containing the fitted model.}
#'  \item{\code{rawdata}}{\code{"data.frame"} containing the raw data used to fit the model, as specified by the user.}
#' } 
#'
#' @importFrom rstan stan rstan_options extract
#' @importFrom mail sendmail
#' @importFrom stats median qnorm
#' @importFrom utils read.table
#'
#' @details 
#' This section describes some of the function arguments in greater detail.
#' 
#' \strong{data} should be assigned a character value specifying the full path and name of the file, including the file extension 
#' (e.g. ".txt"), that contains the behavioral data of all subjects of interest for the current analysis. 
#' The file should be a \strong{tab-delimited} text (.txt) file whose rows represent trial-by-trial observations and columns 
#' represent variables. For choice/reaction-time tasks, there should be three columns of data with the labels "subjID", "choice", and "RT". 
#' It is not necessary for the columns to be in this particular order, however it is necessary that they be labelled 
#' correctly and contain the information below:
#' \describe{
#'  \item{\code{"subjID"}}{A unique identifier for each subject within data-set to be analyzed.}
#'  \item{\code{"choice"}}{An integer representing the choice made on the current trial. Lower/upper boundary or left/right choices should be coded as 1/2 (e.g., 1 1 1 2 1 2).}
#'  \item{\code{"RT"}}{A floating number the choice reaction time in \strong{seconds}. (e.g., 0.435 0.383 0.314 0.309, etc.).}
#' }
#' \strong{*}Note: The data.txt file may contain other columns of data (e.g. "stimulus_name", "trial_number", etc.), but only the data with the column
#' names listed above will be used for analysis/modeling. As long as the columns above are present and labelled correctly,
#' there is no need to remove other miscellaneous data columns.
#'  
#' \strong{nwarmup} is a numerical value that specifies how many MCMC samples should not be stored upon the 
#' beginning of each chain. For those familiar with Bayesian methods, this value is equivalent to a burn-in sample. 
#' Due to the nature of MCMC sampling, initial values (where the sampling chain begins) can have a heavy influence 
#' on the generated posterior distributions. The \strong{nwarmup} argument can be set to a high number in order to curb the 
#' effects that initial values have on the resulting posteriors.  
#' 
#' \strong{nchain} is a numerical value that specifies how many chains (i.e. independent sampling sequences) should be
#' used to draw samples from the posterior distribution. Since the posteriors are generated from a sampling 
#' process, it is good practice to run multiple chains to ensure that a representative posterior is attained. When
#' sampling is completed, the multiple chains may be checked for convergence with the \code{plot(myModel, type = "trace")}
#' command. The chains should resemble a "furry caterpillar".
#' 
#' \strong{nthin} is a numerical value that specifies the "skipping" behavior of the MCMC samples being chosen 
#' to generate the posterior distributions. By default, \strong{nthin} is equal to 1, hence every sample is used to 
#' generate the posterior. 
#' 
#' \strong{Contol Parameters:} adapt_delta, stepsize, and max_treedepth are advanced options that give the user more control 
#' over Stan's MCMC sampler. The Stan creators recommend that only advanced users change the default values, as alterations
#' can profoundly change the sampler's behavior. Refer to Hoffman & Gelman (2014, Journal of Machine Learning Research) for 
#' more information on the functioning of the sampler control parameters. One can also refer to section 58.2 of the  
#' \href{http://mc-stan.org/documentation/}{Stan User's Manual} for a less technical description of these arguments. 
#' 
#' @export 
#' 
#' @references 
#' Ratcliff, R. (1978). A theory of memory retrieval. Psychological Review, 85(2), 59-108. http://doi.org/10.1037/0033-295X.85.2.59
#' 
#' Hoffman, M. D., & Gelman, A. (2014). The No-U-turn sampler: adaptively setting path lengths in Hamiltonian Monte Carlo. The 
#' Journal of Machine Learning Research, 15(1), 1593-1623.
#' 
#' @seealso 
#' We refer users to our in-depth tutorial for an example of using hBayesDM: \url{https://rpubs.com/CCSL/hBayesDM}
#' 
#' @examples 
#' \dontrun{
#' # Run the model and store results in "output"
#' output <- choiceRT_ddm(data = "example", niter = 2000, nwarmup = 1000, nchain = 3, ncore = 3)
#' 
#' # Visually check convergence of the sampling chains (should like like 'hairy caterpillars')
#' plot(output, type = 'trace')
#' 
#' # Check Rhat values (all Rhat values should be less than or equal to 1.1)
#' rhat(output)
#' 
#' # Plot the posterior distributions of the hyper-parameters (distributions should be unimodal)
#' plot(output)
#' 
#' # Show the WAIC and LOOIC model fit estimates 
#' printFit(output)
#' }

choiceRT_ddm <- function(data           = "choose",
                         niter          = 3000, 
                         nwarmup        = 1000, 
                         nchain         = 2,
                         ncore          = 2, 
                         nthin          = 1,
                         inits          = "fixed",  
                         indPars        = "mean", 
                         saveDir        = NULL,
                         email          = NULL,
                         RTbound        = 0.1,
                         modelRegressor = FALSE,
                         adapt_delta    = 0.95,
                         stepsize       = 1,
                         max_treedepth  = 10 ) {
  
  # Path to .stan model file
  if (modelRegressor) { # model regressors (for model-based neuroimaging, etc.)
    stop("** Model-based regressors are not available for this model **\n")
  } 
  
  # To see how long computations take
  startTime <- Sys.time()    

  # For using example data
  if (data=="example") {
    data <- system.file("extdata", "choiceRT_exampleData.txt", package = "hBayesDM")
  } else if (data == "choose") {
    data <- file.choose()
  }
  
  # Load data
  if (file.exists(data)) {
    rawdata <- read.table( data, header = T )
  } else {
    stop("** The data file does not exist. Please check it again. **\n  e.g., data = '/MyFolder/SubFolder/dataFile.txt', ... **\n")
  }    
  
  # Individual Subjects
  subjList <- unique(rawdata[,"subjID"])  # list of subjects x blocks
  numSubjs <- length(subjList)  # number of subjects
  
  # Specify the number of parameters and parameters of interest 
  numPars <- 4
  POI     <- c("mu_alpha", "mu_beta", "mu_delta", "mu_tau",
               "sigma",
               "alpha", "beta", "delta", "tau", 
               "log_lik")
  
  # parameters of the DDM (parameter names in Ratcliffs DDM), from https://github.com/gbiele/stan_wiener_test/blob/master/stan_wiener_test.R
  # alpha (a): Boundary separation or Speed-accuracy trade-off (high alpha means high accuracy). alpha > 0
  # beta (b): Initial bias Bias for either response (beta > 0.5 means bias towards "upper" response 'A'). 0 < beta < 1
  # delta (v): Drift rate Quality of the stimulus (delta close to 0 means ambiguous stimulus or weak ability). 0 < delta
  # tau (ter): Nondecision time + Motor response time + encoding time (high means slow encoding, execution). 0 < ter (in seconds)
  
  modelName <- "choiceRT_ddm"

  # Information for user
  cat("\nModel name = ", modelName, "\n")
  cat("Data file  = ", data, "\n")
  cat("\nDetails:\n")
  cat(" # of chains                       = ", nchain, "\n")
  cat(" # of cores used                   = ", ncore, "\n")
  cat(" # of MCMC samples (per chain)     = ", niter, "\n")
  cat(" # of burn-in samples              = ", nwarmup, "\n")
  cat(" # of subjects                     = ", numSubjs, "\n")
  
  ################################################################################
  # THE DATA.  ###################################################################
  ################################################################################
  
  Tsubj <- as.vector( rep( 0, numSubjs ) ) # number of trials for each subject

  for ( i in 1:numSubjs )  {
    curSubj  <- subjList[i]
    Tsubj[i] <- sum( rawdata$subjID == curSubj )  # Tsubj[N]
  }
  
  # Setting maxTrials
  maxTrials <- max(Tsubj)
  
  # Information for user continued
  cat(" # of (max) trials of this subject = ", maxTrials, "\n\n")
  
  # Number of upper and lower boundary responses for each subject
  Nu <- with(rawdata, aggregate(choice==2, by=list(y=subjID), FUN=sum)[["x"]])
  Nl <- with(rawdata, aggregate(choice==1, by=list(y=subjID), FUN=sum)[["x"]])
  
  # Minimum reaction time per subject
  minRT <- with(rawdata, aggregate(RT, by=list(y=subjID), FUN=min)[["x"]])
  
  # Reaction times for upper and lower boundary responses
  RTu <- array(0, c(numSubjs, max(Nu)) ) 
  RTl <- array(0, c(numSubjs, max(Nl)) )
  
  # Store each subjects' reaction time data
  for (i in 1:numSubjs) {
    curSubj         <- subjList[i]
    tmp             <- subset(rawdata, rawdata$subjID == curSubj)
    RTu[i, 1:Nu[i]] <- tmp$RT[tmp$choice==2] # (Nu/Nl[i]+1):Nu/Nl_max will be padded with 0's 
    RTl[i, 1:Nl[i]] <- tmp$RT[tmp$choice==1] # 0 padding is skipped in likelihood calculation
  }

  # List of data sent to Stan
  dataList <- list(
    N       = numSubjs, # Number of subjects
    Nu_max  = max(Nu),  # Max (across subjects) number of upper boundary responses
    Nl_max  = max(Nl),  # Max (across subjects) number of lower boundary responses
    Nu      = Nu,       # Number of upper boundary responses for each subj
    Nl      = Nl,       # Number of lower boundary responses for each subj
    RTu     = RTu,      # upper boundary response times
    RTl     = RTl,      # lower boundary response times
    minRT   = minRT,    # minimum RT for each subject of the observed data 
    RTbound = RTbound   # lower bound or RT across all subjects (e.g., 0.1 second)
  )
  
  # inits
  if (inits[1] != "random") {
    if (inits[1] == "fixed") {
      inits_fixed <- c(0.5, 0.5, 0.5, 0.15)
    } else {
      if (length(inits)==numPars) {
        inits_fixed <- inits
      } else {
        stop("Check your inital values!")
      }
    }
    genInitList <- function() {
      list(
        mu_p     = c( log(inits_fixed[1]), qnorm(inits_fixed[2]), log(inits_fixed[3]), qnorm(inits_fixed[4]) ),
        sigma    = c(1.0, 1.0, 1.0, 1.0),
        alpha_pr = rep( log(inits_fixed[1]), numSubjs),
        beta_pr  = rep( qnorm(inits_fixed[2]), numSubjs),
        delta_pr = rep( log(inits_fixed[3]), numSubjs),
        tau_pr   = rep( qnorm(inits_fixed[4]), numSubjs)
      )
    }
  } else {
    genInitList <- "random"
  }
    
  if (ncore > 1) {
    numCores <- parallel::detectCores()
    if (numCores < ncore){
      options(mc.cores = numCores)
      warning('Number of cores specified for parallel computing greater than number of locally available cores. Using all locally available cores.')
    }
    else{
      options(mc.cores = ncore)
    }
  }
  else {
    options(mc.cores = 1)
  }
  
  cat("***********************************\n")
  cat("**  Loading a precompiled model  **\n")
  cat("***********************************\n")
  
  # Fit the Stan model
  m = stanmodels$choiceRT_ddm
  fit <- rstan::sampling(m,
                         data   = dataList, 
                         pars   = POI,
                         warmup = nwarmup,
                         init   = genInitList, 
                         iter   = niter, 
                         chains = nchain,
                         thin   = nthin,
                         control = list(adapt_delta   = adapt_delta, 
                                        max_treedepth = max_treedepth, 
                                        stepsize      = stepsize) )
  
  parVals <- rstan::extract(fit, permuted=T)
  
  alpha <- parVals$alpha
  beta  <- parVals$beta
  delta <- parVals$delta
  tau   <- parVals$tau

  # Individual parameters (e.g., individual posterior means)
  allIndPars <- array(NA, c(numSubjs, numPars))
  allIndPars <- as.data.frame(allIndPars)
                 
  for (i in 1:numSubjs) {
    if (indPars=="mean") {
      allIndPars[i, ] <- c( mean(alpha[, i]), 
                            mean(beta[, i]),
                            mean(delta[, i]),
                            mean(tau[, i]))
    } else if (indPars=="median") {
      allIndPars[i, ] <- c( median(alpha[, i]),
                            median(beta[, i]),
                            median(delta[, i]),
                            median(tau[, i]))
    } else if (indPars=="mode") {
      allIndPars[i, ] <- c( estimate_mode(alpha[, i]),
                            estimate_mode(beta[, i]),
                            estimate_mode(delta[, i]),
                            estimate_mode(tau[, i]))
    }
  }
  allIndPars           <- cbind(allIndPars, subjList)
  colnames(allIndPars) <- c("alpha", 
                            "beta",
                            "delta",
                            "tau",
                            "subjID")
  
  # Wrap up data into a list
  modelData        <- list(modelName, allIndPars, parVals, fit, rawdata)
  names(modelData) <- c("model", "allIndPars", "parVals", "fit", "rawdata")  
  class(modelData) <- "hBayesDM"

  # Total time of computations
  endTime  <- Sys.time()
  timeTook <- endTime - startTime
  
  # If saveDir is specified, save modelData as a file. If not, don't save
  # Save each file with its model name and time stamp (date & time (hr & min))
  if (!is.null(saveDir)) {  
    currTime  <- Sys.time()
    currDate  <- Sys.Date()
    currHr    <- substr(currTime, 12, 13)
    currMin   <- substr(currTime, 15, 16)
    timeStamp <- paste0(currDate, "_", currHr, "_", currMin)
    dataFileName = sub(pattern = "(.*)\\..*$", replacement = "\\1", basename(data))
    save(modelData, file=file.path(saveDir, paste0(modelName, "_", dataFileName, "_", timeStamp, ".RData"  ) ) )
  }
  
  # Send email to notify user of completion
  if (is.null(email)==F) {
    mail::sendmail(email, paste("model=", modelName, ", fileName = ", data),
             paste("Check ", getwd(), ". It took ", as.character.Date(timeTook), sep="") )
  }
  # Inform user of completion
  cat("\n************************************\n")
  cat("**** Model fitting is complete! ****\n")
  cat("************************************\n")
  
  return(modelData)
}
