import java.time.LocalDateTime;
import java.util.List;

import cartago.*;

public class ParkControl extends Artifact {
    private KeyValueObject extrairDados(Object[] campo) {
        String key = campo[0].toString();
        String value = campo[1].toString();
        return new KeyValueObject(key, value);
    }

    private Vaga preencherVaga(Object[] metaDataList) {
        Vaga vaga = new Vaga("", "");
        for (Object metaData : metaDataList) {
            KeyValueObject object = extrairDados((Object[]) metaData);
            if (object.getKey().equals("status")) {
                vaga.setStatus(object.getValue());
            } else if (object.getKey().equals("tipo")) {
                vaga.setTipoVaga(object.getValue());
            } else if (object.getKey().equals("reservas")) {
                vaga.setReservas(object.getValue());
            }
        }
        return vaga;
    }

    @OPERATION
    void verificarCompra(String type, Object[] metaDataList, OpFeedbackParam<Boolean> status) {
        Vaga vaga = preencherVaga(metaDataList);
        LocalDateTime currentDateTime = LocalDateTime.now();
        Long date = Funcoes.toUnixTimestamp(currentDateTime);

        if (vaga.getStatus().equals("disponivel") && vaga.getTipoVaga().equals(type)) {
            if (verificarData(date, vaga)) {
                // log("Vaga disponível: " + vaga.getTipoVaga());
                status.set(true);
                return;
            }
        }
        status.set(false);
    }

    private boolean verificarData(Long data, Vaga vaga) {
        for (Reserva reserva : vaga.getReservas()) {
            Long dataInicio = Long.valueOf(reserva.getData());
            Long dataFinal = reserva.getDataFinalPrevista();
            if (Funcoes.isBetweenDates(data, dataInicio, dataFinal)) {
                return false;
            }
        }
        return true;
    }

    @OPERATION
    void verificarReserva(String idVaga, String tipo, String dataString, int duracao, Object[] metaDataList) {
        Long date = Long.parseLong(dataString);
        Vaga vaga = preencherVaga(metaDataList);

        if (!vaga.getStatus().equals("disponivel") || !vaga.getTipoVaga().equals(tipo)) {
            defineObsProperty("reservaDisponivel", false);
            return;
        }

        if (!verificarData(date, Funcoes.getDateWithMinutesAfter(date, duracao),
                vaga.getReservas())) {
            defineObsProperty("reservaDisponivel", false);
            return;
        }

        // log("Vaga disponível: " + vaga.getTipoVaga());
        defineObsProperty("reservaDisponivel", true);
        // defineObsProperty("tipoVaga", vaga.getTipoVaga());
        // defineObsProperty("dataUso", date);
    }

    private boolean verificarData(Long dataInicioDesejada, Long dataFinalDesejada,
            List<Reserva> reservas) {
        for (Reserva reserva : reservas) {
            Long dataInicio = Long.valueOf(reserva.getData());
            Long dataFinalPrevista = reserva.getDataFinalPrevista();

            if (Funcoes.hasConflict(dataInicioDesejada, dataFinalDesejada, dataInicio,
                    dataFinalPrevista))
                return false;
            if (Funcoes.hasConflict(dataInicioDesejada, dataFinalDesejada, dataFinalPrevista,
                    Funcoes.getDateWithMinutesAfter(dataFinalPrevista, 30)))
                return false;
        }
        return true;
    }

    @OPERATION
    void getVacancyInfo(Object[] dataList) {
        int isDone = 0;

        for (Object data : dataList) {
            KeyValueObject object = extrairDados((Object[]) data);
            if (object.getKey().equals("tipo")) {
                defineObsProperty("tipoVaga", object.getValue());
                isDone++;
            }
            if (object.getKey().equals("status")) {
                defineObsProperty("statusVaga", object.getValue());
                isDone++;
            }
            if (isDone == 2) {
                return;
            }
        }
        if (isDone == 1) {
            defineObsProperty("statusVaga", "disponivel");
        }

        return;
    }

    @OPERATION
    void registrarReserva(Object[] registrado, String status, String reservaId, String data,
            int tempo) {
        String registro;
        Reserva reserva = new Reserva(reservaId, data, tempo);
        for (Object dados : registrado) {
            KeyValueObject object = extrairDados((Object[]) dados);
            if (object.getKey().equals("reservas")) {
                registro = Reserva.tratarRegistro(object, reserva, status);
                defineObsProperty("reservation", registro);
                return;
            }
        }
        registro = Reserva.tratarRegistro(reserva, status);
        defineObsProperty("reservation", registro);
    }

    @OPERATION
    void acharReserva(String reservaId, String assetId, Object[] metadata) {
        Vaga vaga = preencherVaga(metadata);
        for (Reserva reserva : vaga.getReservas()) {
            if (reservaId.equals(reserva.getId())) {
                defineObsProperty("reservaEncontrada", assetId);
                vaga.getReservas().remove(reserva);
                if (vaga.getReservas().size() == 0) {
                    defineObsProperty("novoRegistro", "status:ocupado");
                    return;
                }
                String listaReservas = "status:ocupado;reservas:["
                        + Vaga.convertReservationsToString(vaga.getReservas()) + "]";
                defineObsProperty("novoRegistro", listaReservas);
                return;
            }
        }
    }

    @OPERATION
    void preparandoLiberacao(Object[] metadata, OpFeedbackParam<String> novoRegistro) {
        Vaga vaga = preencherVaga(metadata);
        if (vaga.getReservas().size() == 0) {
            novoRegistro.set("status:disponivel");
            return;
        }

        novoRegistro.set("status:disponivel;reservas:["
                + Vaga.convertReservationsToString(vaga.getReservas()) + "]");
    }

    @OPERATION
    void calcularValorAPagarUso(String tipoVaga, int minutos, OpFeedbackParam<Double> valorAPagar) {
        double preco = ParkPricing.getPreco(TipoVagaEnum.setTipoVaga(tipoVaga));
        // log("Preço da tabela: " + preco);
        preco = Math.round(preco * ((double) minutos / 60));
        // log("Valor a pagar: " + preco);

        valorAPagar.set(preco);
    }
}
