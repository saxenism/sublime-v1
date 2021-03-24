docker rm -f sublime_contracts
docker build -t sublime .

docker rmi -f `docker images -f "dangling=true" -q`
docker run -v ${PWD}:/home/app -d --name=sublime_contracts sublime

docker exec -it sublime_contracts bash