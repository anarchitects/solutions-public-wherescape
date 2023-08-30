Overview
The out of the box job dependency handling in WhereScape RED is quite complex and is based on starting a job that has been made dependent on a previous job rather than the more traditional way of having a job kick off another job on completion.

To overcome this we have developed a process that utilises a powershell script that in conjunction with a config file can be scheduled as a task in a job to kick off another job. The easiest way to implement this is to have it scheduled as the last task of a job but it could also be used partway through a job.

On the Builder tab under Host Script you will find two scripts:

run_dependent_jobs_config

run_dependent_jobs_powershell


The only one that needs to be scheduled is the run_dependent_jobs_powershell and it can be added to as many jobs as necessary in order to build up your desired dependency chain.

https://stackoverflow.com/questions/14494747/how-to-add-images-to-readme-md-on-github
