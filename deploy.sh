#!/bin/sh
#./deploy.sh CRG DSV 01 App_Test

TYPE=$1
ENV=$2
APP=$4
NUMBER=$3
ROLLBACK=$5

echo "Parâmetros recebidos: "
echo $1 $2 $3 $4 $5 

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -ge 4 ] || die "Os 4 argumentos são obrigatórios. Apenas $# foram informados"
echo $3 | grep -E -q '^[0-9]+$' || die "O argumento 3 deve ser numérico. $3 não é numérico"

GIT_HASH=$(git log --pretty=format:"%h" -1)
GIT_HASH_PREVIOUS=$(git log --pretty=format:"%h" $GIT_HASH^1 -1)
APP_VERSION=$APP'-v1.1-'$GIT_HASH
APP_VERSION_PREVIOUS=$APP'-v1.1-'$GIT_HASH_PREVIOUS
CONTAINER_EG=$APP

source $IIB_HOME/server/bin/mqsiprofile
PORT=0
x=0

LIST_NODES=$(mqsilist | grep -Po "'.*?'" | grep -v 'http[^;]*')
NODES=$(echo $LIST_NODES | tr " " "\n")

echo "Verificando portas disponíveis..."
for item in $NODES
do
  LIST_EG=$(mqsilist ${item//\'} | grep -Po "'.*?'")
  EG=$(echo $LIST_EG | tr " " "\n")
  
  for item_eg in $EG
  do
     if [ $item_eg != $item ]; then
       cmd=$(mqsireportproperties ${item//\'} -e ${item_eg//\'} -o HTTPConnector -n port)
       x=$(echo "$cmd" | sed -n 2p)
     fi

     if [ "$x" -gt "$PORT" ]; then
       PORT=$x
     fi
  done
done

HTTP_PORT=$(echo `expr $PORT + 1`)
HTTPS_PORT=$(echo `expr $HTTP_PORT + 1`)

echo "Gerando arquivo .bar..."
echo "Workspace: $JENKINS_HOME"  
mqsipackagebar -a $APP_VERSION.bar -w "$JENKINS_HOME/workspace" -k $JOB_NAME

ENVS=( "DSV" "QA" "HOM" )

for i in "${ENVS[@]}"
do
   ENV=$i
   BROKER=BRAMIL$TYPE$ENV$NUMBER
   echo "Preparando $BROKER..."

   EGs=$(mqsilist $BROKER)
        
   if [[ $CONTAINER_EG = *"$EGs"* ]]
   then
      echo "Execution grupo $CONTAINER_EG já existe e não será criado."
   else
      echo "Execution group $CONTAINER_EG não existe e será criado."
      mqsicreateexecutiongroup $BROKER -e $CONTAINER_EG
      if [ $? -eq 0 ]
      then
         echo "Execution group $CONTAINER_EG criado com sucesso!"
      else
         echo "Erro na criacao do execution group $CONTAINER_EG"
      fi
   fi

   echo "Setando listeners HTTP ($HTTP_PORT)/HTTPS($HTTPS_PORT)..."
   echo $CONTAINER_EG

   mqsichangeproperties $BROKER -e $CONTAINER_EG -o ExecutionGroup -n httpNodesUseEmbeddedListener -v true
   mqsichangeproperties $BROKER -e $CONTAINER_EG -o ExecutionGroup -n soapNodesUseEmbeddedListener -v true
   mqsichangeproperties $BROKER -e $CONTAINER_EG -o HTTPConnector -n explicitlySetPortNumber -v $HTTP_PORT
   mqsichangeproperties $BROKER -e $CONTAINER_EG -o HTTPSConnector -n explicitlySetPortNumber -v $HTTPS_PORT

   echo "Configurando log4j..."
   LOG4J_CONFIG_DIR=/var/mqsi/config/$BROKER/$CONTAINER_EG/shared-classes/log4j.jar
   #mkdir -p $LOG4J_CONFIG_DIR
   #cp log4j.xml $LOG4J_CONFIG_DIR
   echo "Arquivo log4j.xml copiado para $LOG4J_CONFIG_DIR"
   #mqsichangeproperties $BROKER -e $CONTAINER_EG -o ComIbmJVMManager -n jvmSystemProperty -v"-Dlog4j.debug -Dlog4j.configurationFile=file://${LOG4J_CONFIG_DIR}/log4j.xml"

   echo "Reiniciando EG $CONTAINER_EG"
   mqsireload $BROKER -e $CONTAINER_EG

   if [ $ROLLBACK -eq 0 ]
   then
      echo "Iniciando deploy de $APP_VERSION em $CONTAINER_EG..."
      mqsideploy $BROKER -e $CONTAINER_EG -a $APP_VERSION.bar
   else
      echo "Iniciando rollback para versão $APP_VERSION_PREVIOUS em $CONTAINER_EG..."
      mqsideploy $BROKER -e $CONTAINER_EG -a $APP_VERSION_PREVIOUS.bar
   fi
done
echo "Operação concluída!!!"
