# Use an official Ubuntu image as the base image
FROM ubuntu:latest

# Set the working directory to /Chamber
WORKDIR /Chamber

# Copy all files and folders from the current directory to the working directory
COPY . .

# Create a .dockerignore file to exclude files specified in .gitignore
COPY .dockerignore .

# Install any necessary dependencies or perform other setup steps here

# Set the default command to run when the container starts
CMD ["/bin/bash"]
