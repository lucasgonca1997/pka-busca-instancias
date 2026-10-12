# PKA - Busca de instâncias

Automação de busca de instâncias para PokeAlliance em AutoHotkey v2 no Windows.

## Uso

1. Baixe `PKA-Busca-Instancias.exe` na seção **Releases**. Ao abrir, autorize a solicitação de administrador do Windows. O programa só funciona com essa permissão, pois o PKA também é executado como administrador.
2. Abra o PokeAlliance, informe o nome do personagem e, quando o nome estiver visível, clique em **Calibrar**. A posição fica salva no computador.
3. Pressione **F12** para iniciar ou parar. O programa procura instâncias com `0 jogadores`, tenta entrar e apita três vezes.
4. O PKA pode ficar coberto por outras janelas durante a busca. O programa captura a janela do jogo e envia os cliques e a rolagem diretamente a ela, sem ocupar o cursor durante a varredura. Deixe o jogo aberto e sem minimizar.

Na rolagem, o cursor fica sobre a barra lateral da lista para que a descrição de uma instância não cubra o texto `0 jogadores`. A busca testa a largura original desse texto e outras escalas, independentemente do tamanho do botão do painel.

A busca percorre sete passos de rolagem por direção e mantém o painel aberto entre as varreduras. A interface pode ser minimizada na bandeja.

## Atualizações

O executável verifica a versão mais recente no GitHub ao abrir. Quando há uma versão nova, pede confirmação, baixa o novo executável, confere o SHA-256 publicado pelo GitHub, substitui o arquivo atual e reinicia. As configurações do personagem e da calibração ficam em `%APPDATA%\PKA-Automacao\config.ini`.

A partir de `v1.0.1`, o executável exige administrador antes de iniciar. Ao atualizar a partir da `v1.0.0`, o Windows solicitará essa permissão na primeira abertura da nova versão.

Versões distribuídas antes de `v1.0.0` não contêm o atualizador e precisam ser substituídas manualmente uma vez. Para que versões futuras sejam encontradas, publique uma **Release** com tag `vX.Y.Z` e o anexo com o nome exato `PKA-Busca-Instancias.exe`.

## Compilar

Mantenha os arquivos desta pasta juntos e compile `PKA-Busca-Instancias.ahk` com AutoHotkey v2 / Ahk2Exe, usando a base de 64 bits. O `.exe` incorpora `0-jogador.png`, `wincapture.dll` e `pka-update.ps1`.

`wincapture.ahk` e `wincapture.dll` pertencem à biblioteca [ahk2_lib](https://github.com/thqby/ahk2_lib/tree/master/wincapture) de thqby. Consulte `wincapture-LICENSE.txt` para a licença MIT dessa dependência.

A versão 1.0.4 reativou a busca com o PKA coberto. Na 1.0.5, o programa aguarda a confirmação da abertura do painel antes de tentar novo clique e deixa o painel aberto enquanto procura vagas. Se um cliente ignorar os cliques enviados em segundo plano, o programa pode trazer o jogo à frente apenas após encontrar uma vaga para concluir a entrada.
