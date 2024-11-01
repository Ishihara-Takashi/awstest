locals {
  name   = replace(basename(path.cwd), "_", "-")
  region = "ap-northeast-1"
  app    = "go-simple-server"
}
