import cartago.*;
import java.util.HashMap;
import java.util.Map;

public class ParkPricing extends Artifact { 
    private static Map<TipoVagaEnum, Double> precos;
    
    void init() {
        precos = new HashMap<>();
        precos.put(TipoVagaEnum.CURTA, 10.0);
        precos.put(TipoVagaEnum.LONGA, 14.0);
        precos.put(TipoVagaEnum.CURTACOBERTA, 18.0);
        precos.put(TipoVagaEnum.LONGACOBERTA, 20.0);
    }

    public static Double getPreco(TipoVagaEnum tipoVaga) {
        return precos.getOrDefault(tipoVaga, 0.0);
    }

    @OPERATION
    void consultPrice(String tipoVaga) {
        if (tipoVaga != null) {
            TipoVagaEnum typeVaga = TipoVagaEnum.setTipoVaga(tipoVaga);
            Double precoTabela = getPreco(typeVaga);
            defineObsProperty("precoTabela", precoTabela.intValue());
        }
    }

    @OPERATION
    void consultTable(String tipoVaga) {
        if (tipoVaga != null) {
            TipoVagaEnum typeVaga = TipoVagaEnum.setTipoVaga(tipoVaga);
            Double precoTabela = getPreco(typeVaga);

            defineObsProperty("precoTabela", precoTabela);
        }
    }
}