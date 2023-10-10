# Deploy on Azure Cloud with Terraform
# Pipeline Architecture
![image](https://github.com/danjelhysenaj-dev/Infrastructure-as-Code/assets/72606127/5acd6ed2-09bd-492b-89a3-1ca409959eae)

# What we will include in this pipeline in order to deploy on Azure
- Working with Azure DevOps services such as Azure repos like (creating branches, pull requests, code reviews) Azure Pipelines, Azure Artifacts, etc.
- Creating Terraform backend, SPN (Service Principal), Key Vaults & secrets on Azure with CLI PowerShell script.
- It will include creating a Terraform Multi-Stage YAML pipeline with Manual Validation task, Artifacts, Approvals, Triggers, and much more.
- Integrating Azure keyvault, Terraform and Azure DevOps Pipeline Libraries.

# Description of Pipeline Architecture
1.  A DevOps Engineer initiates the creation of a new branch for either amending or generating fresh code.
2.  The code is then committed to this newly created branch, but only on a local level.
3.  Subsequently, the engineer pushes this code from their local environment to the remote repository in Azure DevOps.
4.  The DevOps Engineer takes a step further by initiating a pull request, aiming to merge this code into the main branch, which stems from the branch created in the first step.
5.  Following this, a pipeline is triggered to perform validation and planning tasks with Terraform.
6.  In tandem with this pull request, an automatic code review request is sent out to other engineers.
7.  If the code review results in rejection, the pull request may be closed, and the code revised to restart the process.
8.  Once the merge is successfully completed, it triggers the Terraform Build & Release pipeline.
9.  Before this pipeline commences, approval is required.
10. The pipeline is set into motion, with the Terraform "Plan" stage taking the lead.
11. A copy of the tf.plan file is made and stored as an artifact, reserved for use in the "Apply" stage (step 12).
12. Reviewers carefully inspect the Terraform plan to ensure it aligns with the intended deployment; if not, the release can be declined. If everything is in order, we proceed to the Terraform "Apply" stage.
13. The Terraform "Apply" stage is then initiated, leading to the deployment and/or destruction of resources.


TODO: Give a short introduction of your project. Let this section explain the objectives or the motivation behind this project. 

# Getting Started
TODO: Guide users through getting your code up and running on their own system. In this section you can talk about:
1.	Installation process
2.	Software dependencies
3.	Latest releases
4.	API references

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Contribute
TODO: Explain how other users and developers can contribute to make your code better. 

If you want to learn more about creating good readme files then refer the following [guidelines](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-a-readme?view=azure-devops). You can also seek inspiration from the below readme files:
- [ASP.NET Core](https://github.com/aspnet/Home)
- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Chakra Core](https://github.com/Microsoft/ChakraCore)
