{ include("$jacamo/templates/common-cartago.asl") }
{ include("$jacamo/templates/common-moise.asl") }

/* Initial beliefs */

/* Initial goals */
!escolher.

/* Plans */

+decisao(X) : true <- .print("Escolha: ", X).

+vagaDisponivel(Status)[source(manager)] : Status == true <-
    .wait(3000);
    ?idVaga(Id);
    ?decisao(Choice);
    ?dataUso(Data);
    if (Choice == "COMPRA") {
        !estacionar;
    } elif (Choice == "RESERVA") {
        !reservar(Id, Data);
    } else {
        .print("Escolha invalida");
    }.

+vagaDisponivel(Status) : Status == false <-
    .print("Vaga indisponivel").

+reservationNFT(AssetId, TransactionId)[source(manager)] <- 
    !stampProcess(TransactionId);
    .print("Reserva recebida");
    defineReservationChoice(AssetId).

+reservationAvailable(Type,Date,Min)[source(driver)] <-
    .print("Motorista colocou a reserva disponivel").

+!escolher : true <-
    .wait(estacionamentoAberto);
    // balanceNFT <---------- verificar se tem alguma reserva na carteira
    defineChoice;
    .print("Criando conta bancaria");
    !criarCarteira;
    !obterConteudoCarteira;
    .wait(coinBalance(Balance));
	.send(manager,askOne,managerWallet(Manager),Reply);
	.wait(5000);
	+Reply;
    !comecarNegociacao.

// ----------------- ACOES CARTEIRA -----------------

+!criarCarteira : not myWallet(PrK,PuK) <-
    .print("Obtendo carteira...");
    velluscinum.loadWallet(myWallet);
	.wait(myWallet(PrK,PuK));
    +driverWallet(PuK).

+!obterConteudoCarteira : chainServer(Server) & myWallet(PrK, PuK)
            & cryptocurrency(Coin) <-
    .print("Obtendo conteudo da carteira...");
    velluscinum.walletContent(Server, PrK, PuK, content);
    .wait(content(Content));
    !findToken(Coin, set(Content)).

+!findToken(Term,set([Head|Tail])) <- 
    !compare(Term,Head,set(Tail));
    !findToken(Term,set(Tail)).

+!compare(Term,[Type,AssetID, Qtd],set(V)): (Term  == Type) | (Term == AssetID) <- 
    .print("Type: ", Type, " ID: ", AssetID," Qtd: ", Qtd);
	+coinBalance(Qtd).

-!compare(Term,[Type,AssetID,Qtd],set(V)) <- .print("The Asset ",AssetID, " is not a ",Term).

-!findToken(Type,set([   ])): not coinBalance(Amount) <- 
	.print("Moeda Nao encontrada");
    !pedirEmprestimo.

-!findToken(Type,set([   ])): coinBalance(Amount) <- 
	.print("Saldo atual: ", Amount).

+!pedirEmprestimo : cryptocurrency(Coin) & bankWallet(BankW) 
            & chainServer(Server) & myWallet(PrK,PuK)
            & not pedindoEmprestimo <-
    +pedindoEmprestimo;
    emprestimoCount;
	.print("Pedindo emprestimo...");
    ?emprestimoNum(Num);
    .concat("nome:motorista;emprestimo:", Num, Data);
	velluscinum.deployNFT(Server, PrK, PuK, Data,
                "description:Creating Bank Account", account);
	.wait(account(AssetID));

	velluscinum.transferNFT(Server, PrK, PuK, AssetID, BankW,
				"description:requesting lend;value_chainCoin:100",requestID);
	.wait(requestID(PP));
	
	.print("Lend Contract nr:",PP);
	.send(bank, achieve, lending(PP, PuK, 100));
    .wait(bankAccount(ok));
    -pedindoEmprestimo;
    !obterConteudoCarteira.

+!pedirEmprestimo : pedindoEmprestimo <-
    .print("Ja esta pedindo emprestimo").

+!pedirEmprestimo : true <-
    .print("Erro ao pedir emprestimo");
    .wait(5000);
    !pedirEmprestimo.

// -------------------- CENARIOS --------------------
// ----- USO -----

+vagaOcupada(Id)[source(manager)] <-
    .print("Vaga ocupada");
    ?tempoUso(Min);
    .wait(Min*10);
    !comprar.

+valorAPagarUso(Value)[source(manager)] <- !pagarUso(Value).

+!comecarNegociacao[source(self)] : decisao(EscolhaDriver) & tipoVaga(Tipo) 
            & tempoUso(Tempo) <-
    consultPrice(Tipo, Tempo);
    ?precoTabela(Price);
    ?dataUso(Data);
    
    .print("Tipo da vaga: ", Tipo);
    .print("Tempo de uso: ", Tempo, " minutos");
    .print("Preco total da vaga: ", Price);
    .print("Data de uso: ", Data);
    .print("Consultando vaga...");
    .send(manager, achieve, consultarVaga(Tipo, Data, EscolhaDriver)).

+!comprar <- 
    .print("Pagamento da vaga");
    ?tempoUso(Minutes);
    ?tipoVaga(Tipo);
    .send(manager, achieve, pagamentoUsoVaga(Tipo, Minutes)).

+!pagarUso(Valor): not managerWallet(Manager) <-
    .wait(5000);
    .send(manager,askOne,managerWallet(Manager),Reply);
    +Reply;
    !pagarUso(Valor).

+!pagarUso(Valor) : cryptocurrency(Coin) & chainServer(Server)
            & myWallet(PrK,PuK) & managerWallet(Manager) 
            & (coinBalance(Balance) & (Balance >= Valor))<-
    .print("Pagamento em andamento...");
    ?idVaga(IdVaga);
    velluscinum.transferToken(Server,PrK,PuK,Coin,Manager,Valor,payment);
    .wait(payment(TransactionId));
    .print("Pagamento realizado");
    .send(manager, achieve, validarPagamento(TransactionId, IdVaga)).

+!pagarUso(Valor) : cryptocurrency(Coin) & chainServer(Server)
            & myWallet(PrK,PuK) & managerWallet(Manager) 
            & (coinBalance(Balance) & (Balance < Valor))<-
    .print("Saldo insuficiente");
    !pedirEmprestimo;
    !pagarUso(Valor).

+!estacionar[source(self)] : tempoUso(Min) & idVaga(Id) <-
    .print("--------------------------------------------------------------");
    .print("Estacionando veiculo na vaga ", Id);
    .send(manager, tell, querEstacionar(Id)).

// ----- RESERVAR -----

+!reservar(Id, Data) : tempoUso(Min) & chainServer(Server) & myWallet(PrK,PuK) 
            & cryptocurrency(Coin) & managerWallet(Manager) <- 
    .print("Pagando reserva...");
    ?precoTabela(Preco);
    velluscinum.transferToken(Server, PrK, PuK, Coin, Manager, Preco, payment);
    .wait(payment(TransactionId));
    .send(manager, tell, pagouReserva(TransactionId, Id, Data, Min)).

+!reservar(Id, Data): not managerWallet(Manager) <-
    .wait(5000);
    .send(manager,askOne,managerWallet(Manager),Reply);
    +Reply;
    !reservar(Id, Data).

+reservationChoice(Choice) <- 
    .print("Escolha de reserva: ", Choice);
    if (Choice == "USAR") {
        !useReservation;
    } elif(Choice == "VENDER") {
        !makeVacancyAvailable;
    } else {
        .print("Escolha invalida");
    }.

// ----- VALIDACAO -----
+!stampProcess(TransactionId)[source(self)] : chainServer(Server)
            & myWallet(PrK,PuK) <-
    .print("Validando transferencia...");
    velluscinum.stampTransaction(Server, PrK, PuK, TransactionId).

// ----------------- ESTACIONAR E DEIXAR ESTACIONAMENTO -----------------

+!estacionar[source(manager)] : tempoUso(Min) & idVaga(Id) <-
    .print("--------------------------------------------------------------");
    .print("Estacionando veiculo na vaga ", Id);
    +parked(Id);
    .wait(Min*10);
    !sairEstacionamento.

+!sairEstacionamento[source(manager)] : true <-
    .print("Saindo do estacionamento");
    -parked(Id);
    .print("--------------------------------------------------------------").

+!sairEstacionamento[source(self)] : true <-
    .print("Saindo da vaga");
    -parked(Id);
    .print("--------------------------------------------------------------");
    !escolher.