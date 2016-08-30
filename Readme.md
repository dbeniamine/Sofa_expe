This repository contains the traces of the experiment on Sofa presented in my Ph.D thesis, and the scenes used for the experiment.

The experiment where run on an old customized version of Sofa, available [here](https://github.com/dbeniamine/Sofa_old).

File hierarchy:

    MarkerFullTree_140331_1650/                         # Experiment traces
        exp.sh                                          # Script used to run the experiment
        initlikwid.sh                                   # Initialize likwid, called bu exp.sh
        parseAndPlot.sh                                 # Extract results and do the original plots
        csv_extractor.pl                                # Extract the results
        analyse.rmd                                     # Do the original analysis
        new_csv_extractor.sh                            # Create new cleaner filtered results, require to run csv_extractor.pl before
        new_analysis.rmd                                # New, more clear analysis
        linear*/                                        # Results for the different scenes
    scenes/                                         # Sofa scenes used for the analysis
