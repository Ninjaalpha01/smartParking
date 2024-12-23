{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }

/* Initial beliefs and rules */
//chainServer("http://testchain.chon.group:9984/"). // remoto
chainServer("http://localhost:9984/"). // local
mensagensEnviadas(0).

/* Initial goals */
!carregarCarteira.

/* Plans */
+!incMensagensEnviadas : mensagensEnviadas(Num) <-
    -+mensagensEnviadas(Num+1).

+!carregarCarteira: chainServer(Server) <-
	.broadcast(tell, chainServer(Server));
	.print("Obtendo carteira digital");
	.velluscinum.loadWallet(myWallet);
	incContadorTransacoesVellus;
	.wait(myWallet(PrK,PuK));
	+bankWallet(PuK);

	.velluscinum.walletContent(Server, PrK, PuK, content);
	incContadorTransacoesVellus;
    .wait(content(Content));
	!findToken(token, set(Content));
	.wait(cryptocurrency(Coin)).

+!findToken(Term,set([Head|Tail])) <- 
    !compare(Term,Head,set(Tail));
    !findToken(Term,set(Tail)).

+!compare(Term,[Type,AssetID, Qtd],set(V)): (Term  == Type) | (Term == AssetID) <- 
    // .print("Type: ", Type, " ID: ", AssetID," Qtd: ", Qtd);
	-+coinBalance(Qtd);
	+cryptocurrency(AssetID).

-!compare(Term,[Type,AssetID,Qtd],set(V)).
	// .print("The Asset ",AssetID, " is not a ",Term).

-!findToken(Type,set([   ])): not cryptocurrency(Coin) <- 
	.print("Moeda Nao encontrada");
	!criarMoeda.

-!findToken(Type,set([   ])): cryptocurrency(Coin) <- 
	.print("Moeda ja na carteira").
	
+!criarMoeda: chainServer(Server) & myWallet(PrK, PuK) <- 
	.print("Criando moeda");
	.velluscinum.deployToken(Server, PrK, PuK, "name:cryptocurrency", 100000, cryptocurrency);
	incContadorTransacoesVellus;
	+coinBalance(100000);
	.wait(cryptocurrency(Coin)).

+!lending(ResquestNumber, ClientWallet, Value)[source(Client)]: 
			cryptocurrency(Coin) & coinBalance(Amount) & myWallet(PrK,PuK) & chainServer(Server) <-
	.print("Olá agente ",Client,", Bem vindo ao SmartBank! - Por favor espere enquanto validamos a transferência.");
	.velluscinum.stampTransaction(Server,PrK,PuK,ResquestNumber,loan(Client));
	incContadorTransacoesVellus;
	if (Amount >= Value) {
		.print("Transferência validada. Aguarde enquanto processamos a transação.");
		.velluscinum.transferToken(Server,PrK,PuK,Coin,ClientWallet,Value,transactionTransfer);
		incContadorTransacoesVellus;
		.print("Transação processada com sucesso. Obrigado por escolher o SmartBank!");
		.send(Client,tell,bankAccount(ok));
		!incMensagensEnviadas;
	} else {
		.print("Não há saldo suficiente para esta moeda. Transação cancelada. Obrigado por escolher o SmartBank!");
		.send(Client,tell,bankAccount(fail));
		!incMensagensEnviadas;
	}.
