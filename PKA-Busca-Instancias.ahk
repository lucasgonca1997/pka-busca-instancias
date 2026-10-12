#Requires AutoHotkey v2.0
;@Ahk2Exe-SetVersion 1.0.4
#SingleInstance Force
#UseHook
#Include wincapture.ahk

if !A_IsAdmin {
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '"'
        else
            Run '*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"'
    } catch {
        MsgBox "Este programa precisa de permissao de administrador para controlar o PKA.", "PKA - Busca de instancias"
    }
    ExitApp
}

SetTitleMatchMode 2
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetMouseDelay -1
SetControlDelay -1
SetKeyDelay -1
SetWinDelay -1

global pastaDados := A_AppData "\PKA-Automacao"
global arquivoConfig := pastaDados "\config.ini"
global imagemEmbutida := pastaDados "\0-jogador.png"
global imagemZero := imagemEmbutida
global erroImagem := ""
global erroNome := ""
global pkaHwnd := 0
global buscaAtiva := false
global buscaOcupada := false
global subindo := true
global inicioBusca := 0
global nomeInicial := ""
global calibracao := {nome: "", rx: 0, ry: 0}
global painelSalvo := {rx: -1, ry: -1, escala: 0}
global tempoPainelMs := 0
global tempoVagaMs := 0
global ciclosSemVaga := 0
global posicaoBusca := 0
global modoFundo := true
global captura := 0
global capturaHwnd := 0
global imagemTela := 0
global telaCx := 0, telaCy := 0, telaCw := 0, telaCh := 0
global telaSx := 1, telaSy := 1
global modelosZero := Map()
global versaoAtual := "1.0.4"
global repositorioGithub := "lucasgonca1997/pka-busca-instancias"
global pidAtual := DllCall("GetCurrentProcessId", "UInt")
global scriptAtualizacao := pastaDados "\pka-update.ps1"
global resultadoAtualizacao := pastaDados "\update-check-" pidAtual ".txt"
global resultadoInstalacao := pastaDados "\update-install-" pidAtual ".txt"
global inicioVerificacaoAtualizacao := 0
global inicioInstalacaoAtualizacao := 0

try {
    if !DirExist(pastaDados)
        DirCreate pastaDados
    ; O PNG precisa estar ao lado do AHK somente durante a compilacao.
    FileInstall "0-jogador.png", imagemEmbutida, 1
    FileInstall "wincapture.dll", pastaDados "\wincapture.dll", 1
    FileInstall "pka-update.ps1", scriptAtualizacao, 1
    if !FileExist(imagemEmbutida) || FileGetSize(imagemEmbutida) = 0
        throw Error("A imagem embutida nao foi extraida.")
} catch as erro {
    MsgBox "Falha ao preparar a imagem 0 jogadores:`n" erro.Message
    ExitApp
}

try nomeInicial := IniRead(arquivoConfig, "Personagem", "Nome", "")
try {
    calibracao.nome := IniRead(arquivoConfig, "Calibracao", "Nome", "")
    calibracao.rx := Number(IniRead(arquivoConfig, "Calibracao", "RelX", "0"))
    calibracao.ry := Number(IniRead(arquivoConfig, "Calibracao", "RelY", "0"))
}
try {
    painelSalvo.rx := Number(IniRead(arquivoConfig, "Painel", "RelX", "-1"))
    painelSalvo.ry := Number(IniRead(arquivoConfig, "Painel", "RelY", "-1"))
    painelSalvo.escala := Number(IniRead(arquivoConfig, "Painel", "Escala", "0"))
}

global MinhaGui := Gui("+AlwaysOnTop", "PKA - Busca de instancias v" versaoAtual)
MinhaGui.SetFont "s10", "Segoe UI"
MinhaGui.AddText "x18 y16 w344", "Nome do personagem"
global editNome := MinhaGui.AddEdit("x18 y42 w344", nomeInicial)
global btnCalibrar := MinhaGui.AddButton("x18 y80 w120 h38", "Calibrar")
global btnBusca := MinhaGui.AddButton("x148 y80 w214 h38", "Iniciar busca (F12)")
MinhaGui.AddText "x18 y125 w344 h24", "Busca com PKA coberto por outras janelas"
global txtCalibracao := MinhaGui.AddText("x18 y158 w344 h23", "Calibração: pendente")
global txtBusca := MinhaGui.AddText("x18 y187 w344 h42", "Status: parada")
global txtPKA := MinhaGui.AddText("x18 y235 w344 h37", "PKA: procurando janela...")
global txtVersao := MinhaGui.AddText("x18 y277 w344 h21", "Versão " versaoAtual)
global btnBandeja := MinhaGui.AddButton("x82 y303 w216 h30", "Minimizar para bandeja")

editNome.OnEvent "Change", AtualizarEstadoCalibracao
btnCalibrar.OnEvent "Click", CalibrarNome
btnBusca.OnEvent "Click", (*) => AlternarBusca()
btnBandeja.OnEvent "Click", MinimizarParaBandeja
MinhaGui.OnEvent "Close", FecharParaBandeja
MinhaGui.OnEvent "Size", AoRedimensionarGui

A_TrayMenu.Delete()
A_TrayMenu.Add "Abrir busca de instancias", AbrirInterface
A_TrayMenu.Add()
A_TrayMenu.Add "Iniciar / parar busca", (*) => AlternarBusca()
A_TrayMenu.Add "Verificar atualizações", (*) => VerificarAtualizacao()
A_TrayMenu.Add()
A_TrayMenu.Add "Sair", (*) => ExitApp()
A_TrayMenu.Default := "Abrir busca de instancias"
A_IconTip := "PKA - Busca de instancias"

Hotkey "F12", HotkeyBusca, "On"
SetTimer EncontrarPKA, 2000
EncontrarPKA()
AtualizarEstadoCalibracao()
MinhaGui.Show "w380 h348"
SetTimer VerificarAtualizacao, -500

VerificarAtualizacao(*) {
    global versaoAtual, repositorioGithub, scriptAtualizacao, resultadoAtualizacao
    global inicioVerificacaoAtualizacao, txtVersao
    if !A_IsCompiled {
        txtVersao.Text := "Versão " versaoAtual " (script; atualização do EXE desativada)"
        return
    }
    try {
        if FileExist(resultadoAtualizacao)
            FileDelete resultadoAtualizacao
        cmd := '"' A_WinDir '\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "' scriptAtualizacao '" -Mode Check -Repository "' repositorioGithub '" -CurrentVersion "' versaoAtual '" -ResultFile "' resultadoAtualizacao '"'
        Run cmd, , "Hide"
        txtVersao.Text := "Versão " versaoAtual " • verificando atualização..."
        inicioVerificacaoAtualizacao := A_TickCount
        SetTimer LerVerificacaoAtualizacao, 350
    } catch as erro {
        txtVersao.Text := "Versão " versaoAtual " • falha na verificação"
    }
}

LerVerificacaoAtualizacao() {
    global resultadoAtualizacao, inicioVerificacaoAtualizacao, txtVersao, versaoAtual
    if !FileExist(resultadoAtualizacao) {
        if A_TickCount - inicioVerificacaoAtualizacao > 15000 {
            SetTimer LerVerificacaoAtualizacao, 0
            txtVersao.Text := "Versão " versaoAtual " • não foi possível verificar"
        }
        return
    }
    SetTimer LerVerificacaoAtualizacao, 0
    try resposta := Trim(FileRead(resultadoAtualizacao, "UTF-8"), "`r`n`t ")
    catch {
        txtVersao.Text := "Versão " versaoAtual " • não foi possível verificar"
        return
    }
    partes := StrSplit(resposta, "`t")
    if partes[1] = "CURRENT" {
        txtVersao.Text := "Versão " versaoAtual " • atualizada"
        return
    }
    if partes[1] != "UPDATE" || partes.Length < 4 {
        txtVersao.Text := "Versão " versaoAtual " • não foi possível verificar"
        return
    }
    txtVersao.Text := "Versão " partes[2] " disponível"
    if MsgBox("A versão " partes[2] " está disponível no GitHub. Baixar, instalar e reiniciar agora?", "Atualização do PKA", "YesNo Iconi") = "Yes"
        InstalarAtualizacao(partes[3], partes[4])
}

InstalarAtualizacao(url, hash) {
    global repositorioGithub, scriptAtualizacao, resultadoInstalacao
    global txtVersao, inicioInstalacaoAtualizacao, pidAtual
    try {
        if FileExist(resultadoInstalacao)
            FileDelete resultadoInstalacao
        cmd := '"' A_WinDir '\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "' scriptAtualizacao '" -Mode Install -Repository "' repositorioGithub '" -ResultFile "' resultadoInstalacao '" -DownloadUrl "' url '" -ExpectedSha256 "' hash '" -Target "' A_ScriptFullPath '" -OldPid ' pidAtual
        Run cmd, , "Hide"
        txtVersao.Text := "Baixando atualização..."
        inicioInstalacaoAtualizacao := A_TickCount
        SetTimer LerInstalacaoAtualizacao, 350
    } catch as erro {
        txtVersao.Text := "Falha ao iniciar atualização: " erro.Message
    }
}

LerInstalacaoAtualizacao() {
    global resultadoInstalacao, inicioInstalacaoAtualizacao, txtVersao, versaoAtual
    if !FileExist(resultadoInstalacao) {
        if A_TickCount - inicioInstalacaoAtualizacao > 120000 {
            SetTimer LerInstalacaoAtualizacao, 0
            txtVersao.Text := "Versão " versaoAtual " • download demorou demais"
        }
        return
    }
    SetTimer LerInstalacaoAtualizacao, 0
    try resposta := Trim(FileRead(resultadoInstalacao, "UTF-8"), "`r`n`t ")
    catch {
        txtVersao.Text := "Versão " versaoAtual " • falha na atualização"
        return
    }
    if resposta = "READY" {
        txtVersao.Text := "Instalando atualização..."
        ExitApp
    }
    txtVersao.Text := "Versão " versaoAtual " • falha na atualização"
    MsgBox StrReplace(resposta, "ERROR`t", ""), "Atualização do PKA"
}

HotkeyBusca(*) {
    if !GetKeyState("Shift", "P")
        AlternarBusca()
}

MinimizarParaBandeja(*) {
    global MinhaGui
    MinhaGui.Hide()
}

FecharParaBandeja(*) {
    global MinhaGui
    MinhaGui.Hide()
    return true
}

AoRedimensionarGui(GuiObj, MinMax, Width, Height) {
    if MinMax = -1
        GuiObj.Hide()
}

AbrirInterface(*) {
    global MinhaGui
    MinhaGui.Show()
    WinActivate "ahk_id " MinhaGui.Hwnd
}

EncontrarPKA() {
    global pkaHwnd, txtPKA, editNome, arquivoConfig
    nome := Trim(editNome.Value)
    janelas := WinGetList("PokeAlliance")
    for hwnd in janelas {
        try {
            titulo := WinGetTitle("ahk_id " hwnd)
            separador := InStr(titulo, " - ")
            nomeJanela := separador ? Trim(SubStr(titulo, separador + 3)) : ""
            if !nome && nomeJanela {
                nome := nomeJanela
                editNome.Value := nome
                IniWrite nome, arquivoConfig, "Personagem", "Nome"
            }
            if nome && StrLower(nomeJanela) = StrLower(nome) {
                pkaHwnd := hwnd
                txtPKA.Text := "PKA: " titulo
                return hwnd
            }
        } catch {
            continue
        }
    }
    pkaHwnd := 0
    txtPKA.Text := nome ? "PKA: janela de '" nome "' não encontrada" : "PKA: informe o nome do personagem"
    return 0
}

AtivarPKA() {
    hwnd := EncontrarPKA()
    if !hwnd
        return 0
    try {
        if WinGetMinMax("ahk_id " hwnd) = -1
            WinRestore "ahk_id " hwnd
        if !WinActive("ahk_id " hwnd) {
            WinActivate "ahk_id " hwnd
            if !WinWaitActive("ahk_id " hwnd, , 1)
                return 0
        }
        return hwnd
    } catch {
        return 0
    }
}

; Durante uma busca, usa o mesmo processo escolhido no F12. A lista de
; janelas e os titulos nao precisam ser consultados a cada ciclo.
AtivarJanelaDaBusca(hwnd) {
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if WinGetMinMax("ahk_id " hwnd) = -1
            WinRestore "ahk_id " hwnd
        if !WinActive("ahk_id " hwnd) {
            WinActivate "ahk_id " hwnd
            if !WinWaitActive("ahk_id " hwnd, , 1)
                return false
        }
        return true
    } catch {
        return false
    }
}

ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch) {
    try {
        WinGetClientPos &cx, &cy, &cw, &ch, "ahk_id " hwnd
        return cw > 650 && ch > 450
    } catch {
        return false
    }
}

CapturarBusca(hwnd) {
    global modoFundo, captura, capturaHwnd, imagemTela
    global telaCx, telaCy, telaCw, telaCh, telaSx, telaSy, pastaDados
    if !modoFundo
        return true
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
        return false
    try {
        if !IsObject(captura) || !IsSet(capturaHwnd) || capturaHwnd != hwnd {
            captura := 0
            captura := wincapture.WGC(hwnd, true, pastaDados "\wincapture.dll")
            captura.isBorderRequired(false)
            capturaHwnd := hwnd
        }
        imagemTela := 0
        Loop 3 {
            try {
                imagemTela := captura.capture(1)
                break
            } catch TimeoutError {
                Sleep 45
            }
        }
        if !IsObject(imagemTela) || imagemTela.width < 650 || imagemTela.height < 450
            return false
        telaCx := cx, telaCy := cy, telaCw := cw, telaCh := ch
        telaSx := imagemTela.width / cw, telaSy := imagemTela.height / ch
        return true
    } catch {
        imagemTela := 0
        captura := 0
        return false
    }
}

PixelGetColorBusca(x, y) {
    global modoFundo, imagemTela, telaCx, telaCy, telaSx, telaSy
    if !modoFundo
        return PixelGetColor(x, y)
    ix := Round((x - telaCx) * telaSx)
    iy := Round((y - telaCy) * telaSy)
    if ix < 0 || iy < 0 || ix >= imagemTela.width || iy >= imagemTela.height
        throw Error("Pixel fora da captura")
    return imagemTela[ix, iy] & 0xFFFFFF
}

PixelSearchBusca(&x, &y, x1, y1, x2, y2, cor, variacao := 0) {
    global modoFundo, imagemTela, telaCx, telaCy, telaSx, telaSy
    if !modoFundo
        return PixelSearch(&x, &y, x1, y1, x2, y2, cor, variacao)
    reverso := x1 > x2
    esquerda := Max(0, Floor((Min(x1, x2) - telaCx) * telaSx))
    direita := Min(imagemTela.width - 1, Ceil((Max(x1, x2) - telaCx) * telaSx))
    topo := Max(0, Floor((Min(y1, y2) - telaCy) * telaSy))
    fundo := Min(imagemTela.height - 1, Ceil((Max(y1, y2) - telaCy) * telaSy))
    if esquerda > direita || topo > fundo
        return false
    trecho := imagemTela.range(esquerda, topo, direita + 1, fundo + 1)
    if !trecho.findColor(&rx, &ry, cor, variacao * 0x010101, reverso ? 1 : 0)
        return false
    x := Round(telaCx + rx / telaSx)
    y := Round(telaCy + ry / telaSy)
    return true
}

ModeloZero(largura) {
    global modelosZero, imagemZero
    if modelosZero.Has(largura)
        return modelosZero[largura]
    hbm := LoadPicture(imagemZero, "w" largura " h-1")
    if !hbm
        throw Error("Não foi possível redimensionar 0-jogador.png")
    try modelo := BitmapBuffer.loadPicture("HBITMAP:" hbm)
    finally DllCall("DeleteObject", "ptr", hbm)
    modelosZero[largura] := modelo
    return modelo
}

ImageSearchBusca(&x, &y, x1, y1, x2, y2, largura, tolerancia) {
    global modoFundo, imagemZero, imagemTela, telaCx, telaCy, telaSx, telaSy
    if !modoFundo
        return ImageSearch(&x, &y, x1, y1, x2, y2,
            "*" tolerancia " *w" largura " *h-1 " imagemZero)
    esquerda := Max(0, Floor((x1 - telaCx) * telaSx))
    direita := Min(imagemTela.width - 1, Ceil((x2 - telaCx) * telaSx))
    topo := Max(0, Floor((y1 - telaCy) * telaSy))
    fundo := Min(imagemTela.height - 1, Ceil((y2 - telaCy) * telaSy))
    if esquerda > direita || topo > fundo
        return false
    modelo := ModeloZero(Max(1, Round(largura * telaSx)))
    if direita - esquerda + 1 < modelo.width || fundo - topo + 1 < modelo.height
        return false
    trecho := imagemTela.range(esquerda, topo, direita + 1, fundo + 1)
    if !trecho.findPic(&rx, &ry, modelo, 1.0, tolerancia * 0x010101)
        return false
    x := Round(telaCx + rx / telaSx)
    y := Round(telaCy + ry / telaSy)
    return true
}

ClicarBusca(hwnd, x, y, botao := "Left") {
    global modoFundo
    if !modoFundo {
        MouseMove x, y, 0
        Click botao
        return
    }
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
        throw Error("Área do jogo indisponível")
    rx := Round(x - cx)
    ry := Round(y - cy)
    pos := (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
    PostMessage 0x0200, 0, pos, , "ahk_id " hwnd
    if botao = "Right" {
        PostMessage 0x0204, 0x0002, pos, , "ahk_id " hwnd
        Sleep 60
        PostMessage 0x0205, 0, pos, , "ahk_id " hwnd
    } else {
        PostMessage 0x0201, 0x0001, pos, , "ahk_id " hwnd
        Sleep 30
        PostMessage 0x0202, 0, pos, , "ahk_id " hwnd
    }
}

FecharPainelBusca(hwnd) {
    global modoFundo
    if modoFundo {
        PostMessage 0x0100, 0x1B, 0x00010001, , "ahk_id " hwnd
        PostMessage 0x0101, 0x1B, 0xC0010001, , "ahk_id " hwnd
    } else
        Send "{Esc}"
}

CorDoBotao(cor) {
    r := (cor >> 16) & 255
    g := (cor >> 8) & 255
    b := cor & 255
    return r <= 12 && g >= 112 && g <= 132 && b >= 180 && b <= 207
}

CorDoCabecalho(cor) {
    r := (cor >> 16) & 255
    g := (cor >> 8) & 255
    b := cor & 255
    return r >= 20 && r <= 70 && g >= 90 && g <= 155 && b >= 140 && b <= 210
}

; Duas amostras confirmam o painel em poucos pixels, mesmo apos reiniciar.
PainelConfere(cx, cy, cw, ch, centroX, centroY, escala) {
    xBotao := Round(centroX + 165 * escala)
    yBotao := Round(centroY + 156 * escala)
    xCabecalho := Round(centroX - 20 * escala)
    yCabecalho := Round(centroY - 183 * escala)
    if xBotao < cx || xBotao >= cx + cw || yBotao < cy || yBotao >= cy + ch
        || xCabecalho < cx || xCabecalho >= cx + cw
        || yCabecalho < cy || yCabecalho >= cy + ch
        return false
    try {
        if CorDoBotao(PixelGetColorBusca(xBotao, yBotao))
            && CorDoCabecalho(PixelGetColorBusca(xCabecalho, yCabecalho))
            return true
    } catch {
    }
    return false
}

; Confirma por uma das duas cores do painel. Um pixel pode variar entre
; aberturas; esta checagem nao procura coordenadas novas.
PainelAbertoNaPosicao(area) {
    hx := Round(area.mx - 20 * area.escala)
    hy := Round(area.my - 183 * area.escala)
    bx := Round(area.mx + 165 * area.escala)
    by := Round(area.my + 156 * area.escala)
    try {
        if hx >= area.cx && hx < area.cx + area.cw
            && hy >= area.cy && hy < area.cy + area.ch
            && CorDoCabecalho(PixelGetColorBusca(hx, hy))
            return true
        if bx >= area.cx && bx < area.cx + area.cw
            && by >= area.cy && by < area.cy + area.ch
            && CorDoBotao(PixelGetColorBusca(bx, by))
            return true
    } catch {
    }
    return false
}

LocalizarJanelaConhecida(hwnd, &mx, &my, &escalaUI) {
    global painelConhecido, painelSalvo
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
        return false
    if IsSet(painelConhecido) && IsObject(painelConhecido) {
        if painelConhecido.hwnd = hwnd && cx = painelConhecido.cx
            && cy = painelConhecido.cy && cw = painelConhecido.cw
            && ch = painelConhecido.ch
            && PainelConfere(cx, cy, cw, ch, painelConhecido.mx,
                painelConhecido.my, painelConhecido.escala) {
            mx := painelConhecido.mx
            my := painelConhecido.my
            escalaUI := painelConhecido.escala
            return true
        }
    }
    if painelSalvo.rx <= 0 || painelSalvo.rx >= 1
        || painelSalvo.ry <= 0 || painelSalvo.ry >= 1
        || painelSalvo.escala <= 0
        return false
    palpiteX := cx + painelSalvo.rx * cw
    palpiteY := cy + painelSalvo.ry * ch
    if !PainelConfere(cx, cy, cw, ch, palpiteX, palpiteY, painelSalvo.escala)
        return false
    mx := palpiteX
    my := palpiteY
    escalaUI := painelSalvo.escala
    painelConhecido := {hwnd: hwnd, cx: cx, cy: cy, cw: cw, ch: ch,
        mx: mx, my: my, escala: escalaUI}
    return true
}

LocalizarJanelaInstancia(hwnd, &mx, &my, &escalaUI) {
    global painelConhecido, painelSalvo, arquivoConfig
    if LocalizarJanelaConhecida(hwnd, &mx, &my, &escalaUI)
        return true
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
        return false
    ; Procura primeiro na area central, depois amplia se o painel foi movido.
    for area in [{x1: Round(cx + cw * 0.20), x2: Round(cx + cw * 0.80),
        y1: Round(cy + ch * 0.18), y2: Round(cy + ch * 0.82)},
        {x1: cx, x2: cx + cw - 1, y1: cy + 120, y2: cy + ch - 1}] {
    ; O botão tem ao menos 23 px de altura e cruza uma linha a cada 8 px.
    Loop Ceil((area.y2 - area.y1 + 1) / 8) {
        linhaY := area.y1 + (A_Index - 1) * 8
        if linhaY > area.y2
            break
        inicioX := area.x1
        Loop 30 {
            try {
                if !PixelSearchBusca(&px, &py, inicioX, linhaY, area.x2, linhaY, 0x0078BD, 12)
                    break
                ; A borda azul tem alguns pixels escuros. Usa a faixa
                ; interna mais larga entre a linha achada e as vizinhas.
                largura := 0
                direita := px
                for deslocamento in [0, -4, 4] {
                    amostraY := py + deslocamento
                    amostraX := px + 8
                    if amostraY < cy || amostraY >= cy + ch || amostraX >= cx + cw
                        continue
                    if !CorDoBotao(PixelGetColorBusca(amostraX, amostraY))
                        continue
                    l := amostraX
                    r := amostraX
                    while l > cx && CorDoBotao(PixelGetColorBusca(l - 1, amostraY))
                        l--
                    while r < cx + cw - 1 && CorDoBotao(PixelGetColorBusca(r + 1, amostraY))
                        r++
                    if r - l + 1 > largura {
                        largura := r - l + 1
                        esquerda := l
                        direita := r
                        faixaY := amostraY
                    }
                }
                if largura >= 105 && largura <= 290 {
                    fator := largura / 138
                    coluna := esquerda + Round(15 * fator)
                    topo := faixaY
                    fundo := faixaY
                    while topo > cy && CorDoBotao(PixelGetColorBusca(coluna, topo - 1))
                        topo--
                    while fundo < cy + ch - 1 && CorDoBotao(PixelGetColorBusca(coluna, fundo + 1))
                        fundo++
                    altura := fundo - topo + 1
                    if altura >= 23 * fator && altura <= 42 * fator {
                        botaoX := (esquerda + direita) / 2
                        botaoY := (topo + fundo) / 2
                        centroX := botaoX - 219 * fator
                        centroY := botaoY - 156 * fator
                        hx := Round(centroX - 20 * fator)
                        hy := Round(centroY - 183 * fator)
                        if hx >= cx && hx < cx + cw && hy >= cy && hy < cy + ch
                            && CorDoCabecalho(PixelGetColorBusca(hx, hy)) {
                            mx := centroX
                            my := centroY
                            escalaUI := fator
                            painelConhecido := {hwnd: hwnd, cx: cx, cy: cy,
                                cw: cw, ch: ch, mx: mx, my: my, escala: fator}
                            painelSalvo := {rx: (mx - cx) / cw,
                                ry: (my - cy) / ch, escala: fator}
                            try {
                                IniWrite Format("{:.8f}", painelSalvo.rx),
                                    arquivoConfig, "Painel", "RelX"
                                IniWrite Format("{:.8f}", painelSalvo.ry),
                                    arquivoConfig, "Painel", "RelY"
                                IniWrite Format("{:.6f}", fator),
                                    arquivoConfig, "Painel", "Escala"
                            }
                            return true
                        }
                    }
                }
                inicioX := direita + 5
                if inicioX >= area.x2
                    break
            } catch {
                return false
            }
        }
    }
    }
    return false
}

; A imagem embutida mede 100 x 30 px. A busca normal percorre apenas a
; coluna dos contadores, cobrindo toda a altura visivel da lista. Isso
; evita perder linhas deslocadas pelo scroll sem varrer o painel inteiro.

ProcurarZero(area, mx, my, escalaUI, &achouX, &achouY, &escalaImagem, rapido := true) {
    global imagemZero, erroImagem
    erroImagem := ""
    if !FileExist(imagemZero) {
        erroImagem := "Imagem 0 jogadores não encontrada: " imagemZero
        return false
    }
    cx := area.cx
    cy := area.cy
    cw := area.cw
    ch := area.ch
    if rapido {
        centroX := Round(mx + 148 * escalaUI)
        margemX := Max(18, Round(24 * escalaUI))
        x1 := Max(cx, centroX - margemX)
        y1 := Max(cy, Round(my - 112 * escalaUI))
        y2 := Min(cy + ch - 1, Round(my + 126 * escalaUI))
        for largura in LargurasZero(escalaUI) {
            x2 := Min(cx + cw - 1, centroX + margemX + largura - 1)
            if x2 - x1 + 1 < largura || y2 - y1 + 1 < Max(12, Round(30 * largura / 100))
                continue
            try {
                if ImageSearchBusca(&x, &y, x1, y1, x2, y2, largura, 55) {
                    achouX := x
                    achouY := y
                    escalaImagem := largura / 100
                    return true
                }
            } catch as erro {
                erroImagem := erro.Message
                return false
            }
        }
        return false
    }
    ; Passagem ampla somente no primeiro ciclo de cada busca. Ela cobre
    ; diferencas de escala antes de continuar nas cinco linhas esperadas.
    x1 := Max(cx, Round(mx - 80 * escalaUI))
    y1 := Max(cy, Round(my - 110 * escalaUI))
    x2 := Min(cx + cw - 1, Round(mx + 285 * escalaUI))
    y2 := Min(cy + ch - 1, Round(my + 125 * escalaUI))
    for largura in LargurasZero(escalaUI) {
        fator := largura / 100
        for tolerancia in [30, 55] {
            try {
                if ImageSearchBusca(&x, &y, x1, y1, x2, y2, largura, tolerancia) {
                    achouX := x
                    achouY := y
                    escalaImagem := fator
                    return true
                }
            } catch as erro {
                erroImagem := erro.Message
                return false
            }
        }
    }
    return false
}

LargurasZero(escalaUI) {
    larguras := []
    vistas := Map()
    ; O texto do jogo pode manter 100 px mesmo se o botao do painel mudar de escala.
    for fator in [1.0, escalaUI, 1.25, 0.9, 1.1, 0.8, 1.5] {
        largura := Max(40, Round(100 * fator))
        if !vistas.Has(largura) {
            vistas[largura] := true
            larguras.Push(largura)
        }
    }
    return larguras
}

SalvarNomePersonagem() {
    global editNome, arquivoConfig
    nome := Trim(editNome.Value)
    if nome
        IniWrite nome, arquivoConfig, "Personagem", "Nome"
    return nome
}

AtualizarEstadoCalibracao(*) {
    global editNome, txtCalibracao, calibracao
    nome := Trim(editNome.Value)
    txtCalibracao.Text := nome && calibracao.nome
        && StrLower(nome) = StrLower(calibracao.nome)
        && calibracao.rx > 0 && calibracao.rx < 1
        && calibracao.ry > 0 && calibracao.ry < 1
        ? "Calibração: salva para " calibracao.nome
        : "Calibração: pendente"
}

; Calibrar e uma acao explicita: depois dela, o nome pode ficar oculto.
; A posicao e guardada como proporcao da area do jogo para acompanhar
; deslocamentos e alteracoes de tamanho da janela.
SalvarCalibracao(hwnd, nome, px, py, &erro) {
    global calibracao, arquivoConfig
    erro := ""
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch) {
        erro := "Área do jogo indisponível."
        return false
    }
    if px < cx || px >= cx + cw || py < cy || py >= cy + ch {
        erro := "Nome fora da área do jogo."
        return false
    }
    rx := (px - cx) / cw
    ry := (py - cy) / ch
    try {
        IniWrite nome, arquivoConfig, "Calibracao", "Nome"
        IniWrite Format("{:.8f}", rx), arquivoConfig, "Calibracao", "RelX"
        IniWrite Format("{:.8f}", ry), arquivoConfig, "Calibracao", "RelY"
        calibracao := {nome: nome, rx: rx, ry: ry}
        AtualizarEstadoCalibracao()
        return true
    } catch as falha {
        erro := "Não foi possível salvar: " falha.Message
        return false
    }
}

ObterPosicaoCalibrada(hwnd, nome, &px, &py) {
    global calibracao
    if !calibracao.nome || StrLower(calibracao.nome) != StrLower(nome)
        return false
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
        return false
    if calibracao.rx <= 0 || calibracao.rx >= 1
        || calibracao.ry <= 0 || calibracao.ry >= 1
        return false
    px := Round(cx + calibracao.rx * cw)
    py := Round(cy + calibracao.ry * ch)
    return true
}

CalibrarNome(*) {
    global buscaAtiva, MinhaGui, txtBusca, erroNome, modoFundo
    if buscaAtiva {
        txtBusca.Text := "Status: pare a busca antes de calibrar"
        return
    }
    nome := SalvarNomePersonagem()
    if !nome {
        txtBusca.Text := "Status: informe o nome do personagem"
        return
    }
    MinhaGui.Hide()
    try {
        modoFundo := false
        hwnd := AtivarPKA()
        if !hwnd {
            txtBusca.Text := "Status: janela de '" nome "' não encontrada"
        } else if !CapturarBusca(hwnd) {
            txtBusca.Text := "Status: captura do PKA indisponível"
        } else if !LocalizarNomePersonagem(hwnd, nome, &px, &py) {
            txtBusca.Text := "Status: " erroNome
        } else if SalvarCalibracao(hwnd, nome, px, py, &erro) {
            txtBusca.Text := "Status: posição salva para " nome
        } else {
            txtBusca.Text := "Status: " erro
        }
    } catch as falha {
        txtBusca.Text := "Erro ao calibrar: " falha.Message
    } finally {
        MinhaGui.Show()
    }
}

LocalizarNomePersonagem(hwnd, nome, &px, &py) {
    global erroNome
    erroNome := ""
    if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch) {
        erroNome := "Área do jogo indisponível."
        return false
    }
    ; Na maioria das cenas o personagem fica perto do centro da area do jogo.
    ; Se o enquadramento for diferente, usa a varredura mais ampla.
    if LocalizarNomeNaArea(hwnd, nome, cx, cy, cw, ch,
        Round(cx + cw * 0.37), Round(cx + cw * 0.63),
        Round(cy + ch * 0.15), Round(cy + ch * 0.55), &px, &py)
        return true
    if SubStr(erroNome, 1, 4) = "Erro" || SubStr(erroNome, 1, 5) = "Falha"
        return false
    return LocalizarNomeNaArea(hwnd, nome, cx, cy, cw, ch,
        Round(cx + cw * 0.25), Round(cx + cw * 0.75),
        Round(cy + ch * 0.08), Round(cy + ch * 0.65), &px, &py)
}

LocalizarNomeNaArea(hwnd, nome, cx, cy, cw, ch, x1, x2, y1, y2, &px, &py) {
    global erroNome, pastaDados, modoFundo, imagemTela, telaSx, telaSy
    erroNome := ""
    if !modoFundo {
        MouseMove cx + 10, cy + 10, 0
        Sleep 70
    }
    grupos := []
    try {
        Loop y2 - y1 + 1 {
            y := y1 + A_Index - 1
            if !PixelSearchBusca(&esquerda, &ignorar, x1, y, x2, y, 0x00BB00, 8)
                continue
            if !PixelSearchBusca(&direita, &ignorar, x2, y, x1, y, 0x00BB00, 8)
                continue
            if !grupos.Length || y - grupos[grupos.Length].yMax > 2 {
                grupos.Push({xMin: esquerda, xMax: direita, yMin: y, yMax: y})
            } else {
                grupo := grupos[grupos.Length]
                grupo.xMin := Min(grupo.xMin, esquerda)
                grupo.xMax := Max(grupo.xMax, direita)
                grupo.yMax := y
            }
        }
    } catch as erro {
        erroNome := "Falha ao localizar etiquetas: " erro.Message
        return false
    }
    regioes := ""
    for grupo in grupos {
        altura := grupo.yMax - grupo.yMin + 1
        largura := grupo.xMax - grupo.xMin + 1
        if altura < 6 || altura > 36 || largura < 15 || largura > 450
            continue
        ; Nomes curtos podem ser confundidos quando o recorte inclui muito
        ; fundo. Primeiro tenta a etiqueta justa; a folgada serve de reserva
        ; para letras maiores ou bordas cortadas.
        for margem in [2, 8] {
            rx := Max(cx, grupo.xMin - margem)
            ry := Max(cy, grupo.yMin - margem)
            rw := Min(cx + cw - 1, grupo.xMax + margem) - rx + 1
            rh := Min(cy + ch - 1, grupo.yMax + margem) - ry + 1
            if rw > 0 && rh > 0 {
                if modoFundo {
                    regioes .= Format("{1},{2},{3},{4}`n",
                        Round((rx - cx) * telaSx), Round((ry - cy) * telaSy),
                        Round(rw * telaSx), Round(rh * telaSy))
                } else
                    regioes .= rx "," ry "," rw "," rh "`n"
            }
        }
    }
    if !regioes {
        erroNome := "Nenhuma etiqueta verde foi encontrada no jogo."
        return false
    }
    arquivoRegioes := pastaDados "\ocr-regioes.txt"
    arquivoResultado := pastaDados "\ocr-resultado.txt"
    arquivoAlvo := pastaDados "\ocr-alvo.txt"
    try {
        PrepararAuxiliarOCR()
        if FileExist(arquivoRegioes)
            FileDelete arquivoRegioes
        if FileExist(arquivoResultado)
            FileDelete arquivoResultado
        if FileExist(arquivoAlvo)
            FileDelete arquivoAlvo
        FileAppend regioes, arquivoRegioes, "UTF-8"
        FileAppend nome, arquivoAlvo, "UTF-8"
        ps := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
        if !FileExist(ps)
            throw Error("Windows PowerShell não encontrado.")
        comando := '"' ps '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' pastaDados '\pka-ocr.ps1" "' arquivoRegioes '" "' arquivoResultado '" -NameFile "' arquivoAlvo '"'
        if modoFundo {
            arquivoCaptura := pastaDados "\ocr-captura.bmp"
            imagemTela.save(arquivoCaptura)
            comando .= ' -ImageFile "' arquivoCaptura '"'
        }
        codigo := RunWait(comando, , "Hide")
        if !FileExist(arquivoResultado)
            throw Error("O OCR não retornou resultado.")
        resultado := FileRead(arquivoResultado, "UTF-8")
        if codigo != 0 {
            erroNome := "Falha no OCR do Windows: " SubStr(resultado, 1, 120)
            return false
        }
        alvo := StrLower(RegExReplace(Trim(nome), "\s+", " "))
        encontrados := []
        for linha in StrSplit(resultado, "`n", "`r") {
            campos := StrSplit(linha, "`t")
            if campos.Length != 3
                continue
            lido := StrLower(RegExReplace(Trim(campos[1]), "\s+", " "))
            if lido = alvo {
                novoX := modoFundo ? Round(cx + Number(campos[2]) / telaSx) : Number(campos[2])
                novoY := modoFundo ? Round(cy + Number(campos[3]) / telaSy) : Number(campos[3])
                repetido := false
                for ponto in encontrados {
                    if Abs(ponto.x - novoX) <= 12 && Abs(ponto.y - novoY) <= 8 {
                        repetido := true
                        break
                    }
                }
                if !repetido
                    encontrados.Push({x: novoX, y: novoY})
            }
        }
        if encontrados.Length = 1 {
            px := encontrados[1].x
            py := encontrados[1].y
            return true
        }
        erroNome := encontrados.Length > 1
            ? "O nome apareceu em mais de um lugar; clique cancelado."
            : "O OCR não encontrou exatamente '" nome "' na tela."
        return false
    } catch as erro {
        erroNome := "Erro ao ler nome: " erro.Message
        return false
    }
}

PrepararAuxiliarOCR() {
    global pastaDados
    static pronto := false
    destino := pastaDados "\pka-ocr.ps1"
    if pronto && FileExist(destino)
        return
    codigo := "
( Join`n
param([string]$RegionsFile, [string]$OutputFile, [string]$ImageFile = "", [string]$NameFile = "")
$ErrorActionPreference = "Stop"
try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Foundation.IAsyncOperation``1, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $awaiter = [WindowsRuntimeSystemExtensions].GetMember("GetAwaiter").Where({$PSItem.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation``1'}, "First")[0]
    if ($null -eq $awaiter) { throw "Awaiter method not found" }
    function Await($task, $type) { $awaiter.MakeGenericMethod($type).Invoke($null, @($task)).GetResult() }
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if ($null -eq $engine) { throw "Windows OCR unavailable" }
    $source = if ($ImageFile) { [System.Drawing.Bitmap]::FromFile($ImageFile) } else { $null }
    $results = New-Object System.Collections.Generic.List[string]
    $target = if ($NameFile) { [System.IO.File]::ReadAllText($NameFile).Trim() } else { "" }
    $rows = New-Object System.Collections.Generic.List[string]
    $rows.AddRange([string[]][System.IO.File]::ReadAllLines($RegionsFile))
    $originalCount = $rows.Count
    $exactFound = $false
    function QueueRefinement($text, $left, $right, $top, $bottom) {
        if (-not $target -or $rows.Count -ge ($originalCount + 9) -or -not $text) { return }
        $at = $text.IndexOf($target, [System.StringComparison]::OrdinalIgnoreCase)
        if ($at -lt 0 -or $text.Trim().Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) { return }
        $unit = ($right - $left) / $text.Length
        $guessLeft = $left + $at * $unit
        $guessRight = $left + ($at + $target.Length) * $unit
        $baseX = [Math]::Round($guessLeft - 13)
        $endX = [Math]::Round($guessRight + 13)
        $startY = [Math]::Round($top - 4)
        $endY = [Math]::Round($bottom + 10)
        foreach ($shift in @(-4, 0, 4)) {
            $rx = $baseX + $shift
            $rw = $endX - $rx
            $rh = $endY - $startY
            if ($rw -ge 30 -and $rh -ge 16) { $rows.Add("$rx,$startY,$rw,$rh") }
        }
    }
    $temp = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputFile)), "ocr-crop-" + $PID + ".bmp")
    for ($index = 0; $index -lt $rows.Count; $index++) {
        if ($index -ge $originalCount -and $exactFound) { break }
        $row = $rows[$index]
        if (-not $row.Trim()) { continue }
        $n = $row.Split(",")
        $x = [int]$n[0]; $y = [int]$n[1]; $w = [int]$n[2]; $h = [int]$n[3]
        $capture = New-Object System.Drawing.Bitmap ($w), ($h)
        $g = [System.Drawing.Graphics]::FromImage($capture)
        if ($source) {
            $g.DrawImage($source, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle $x, $y, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
        } else {
            $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $h))
        }
        $g.Dispose()
        for ($yy = 0; $yy -lt $h; $yy++) {
            for ($xx = 0; $xx -lt $w; $xx++) {
                $p = $capture.GetPixel($xx, $yy)
                if ($p.R -le 20 -and $p.B -le 20 -and $p.G -ge 80 -and $p.G -le 225) {
                    $capture.SetPixel($xx, $yy, [System.Drawing.Color]::Black)
                } else {
                    $capture.SetPixel($xx, $yy, [System.Drawing.Color]::White)
                }
            }
        }
        $scale = [Math]::Min(4, [Math]::Floor(1900 / [Math]::Max($w, $h)))
        if ($scale -lt 2) { $scale = 2 }
        $large = New-Object System.Drawing.Bitmap ($w * $scale), ($h * $scale)
        $g = [System.Drawing.Graphics]::FromImage($large)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.DrawImage($capture, 0, 0, $w * $scale, $h * $scale)
        $g.Dispose(); $capture.Dispose()
        $large.Save($temp, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $large.Dispose()
        $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($temp)) ([Windows.Storage.StorageFile])
        $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
        $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $ocr = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        foreach ($line in $ocr.Lines) {
            if ($line.Words.Count -eq 0) { continue }
            $left = ($line.Words | ForEach-Object {$_.BoundingRect.X} | Measure-Object -Minimum).Minimum
            $right = ($line.Words | ForEach-Object {$_.BoundingRect.X + $_.BoundingRect.Width} | Measure-Object -Maximum).Maximum
            $top = ($line.Words | ForEach-Object {$_.BoundingRect.Y} | Measure-Object -Minimum).Minimum
            $bottom = ($line.Words | ForEach-Object {$_.BoundingRect.Y + $_.BoundingRect.Height} | Measure-Object -Maximum).Maximum
            $px = [Math]::Round($x + ($left + $right) / (2 * $scale))
            $py = [Math]::Round($y + ($top + $bottom) / (2 * $scale))
            $results.Add(($line.Text -replace "``t|``r|``n", " ") + "``t" + $px + "``t" + $py)
            if ($target -and $line.Text.Trim().Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) { $exactFound = $true }
            if ($index -lt $originalCount) {
                QueueRefinement $line.Text ($x + $left / $scale) ($x + $right / $scale) ($y + $top / $scale) ($y + $bottom / $scale)
            }
            if ($line.Words.Count -gt 1) {
                foreach ($word in $line.Words) {
                    $wx = [Math]::Round($x + ($word.BoundingRect.X + $word.BoundingRect.Width / 2) / $scale)
                    $wy = [Math]::Round($y + ($word.BoundingRect.Y + $word.BoundingRect.Height / 2) / $scale)
                    $results.Add(($word.Text -replace "``t|``r|``n", " ") + "``t" + $wx + "``t" + $wy)
                    if ($target -and $word.Text.Trim().Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) { $exactFound = $true }
                    if ($index -lt $originalCount) {
                        QueueRefinement $word.Text ($x + $word.BoundingRect.X / $scale) ($x + ($word.BoundingRect.X + $word.BoundingRect.Width) / $scale) ($y + $word.BoundingRect.Y / $scale) ($y + ($word.BoundingRect.Y + $word.BoundingRect.Height) / $scale)
                    }
                }
            }
        }
        $bitmap.Dispose(); $stream.Dispose()
    }
    if ($source) { $source.Dispose() }
    if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
    [System.IO.File]::WriteAllLines($OutputFile, $results.ToArray(), (New-Object System.Text.UTF8Encoding $false))
} catch {
    [System.IO.File]::WriteAllText($OutputFile, "ERROR``t" + $_.Exception.Message + "``t" + $_.ScriptStackTrace, (New-Object System.Text.UTF8Encoding $false))
    exit 1
}
)"
    if FileExist(destino)
        FileDelete destino
    FileAppend codigo, destino, "UTF-8"
    pronto := true
}

AlternarBusca() {
    global buscaAtiva, btnBusca, txtBusca, imagemZero, MinhaGui, inicioBusca
    global ciclosSemVaga, tempoPainelMs, tempoVagaMs, posicaoBusca, subindo
    global modoFundo
    if buscaAtiva {
        buscaAtiva := false
        SetTimer ProcurarInstancia, 0
        SetTimer EncontrarPKA, 2000
        btnBusca.Text := "Iniciar busca (F12)"
        txtBusca.Text := "Status: parada"
        return
    }
    if !FileExist(imagemZero) {
        txtBusca.Text := "Status: imagem 0 jogadores não encontrada"
        return
    }
    MinhaGui.Hide()
    hwnd := EncontrarPKA()
    if !hwnd {
        txtBusca.Text := "Status: PKA não encontrado ou inacessível"
        MinhaGui.Show()
        return
    }
    nome := SalvarNomePersonagem()
    if !nome {
        txtBusca.Text := "Status: informe o nome do personagem"
        MinhaGui.Show()
        return
    }
    modoFundo := true
    inicioBusca := A_TickCount
    ciclosSemVaga := 0
    subindo := false
    posicaoBusca := 0
    tempoPainelMs := 0
    tempoVagaMs := 0
    buscaAtiva := true
    SetTimer EncontrarPKA, 0
    btnBusca.Text := "Parar busca (F12)"
    txtBusca.Text := "Status: procurando instância (PKA coberto)"
    SetTimer ProcurarInstancia, -1
}

ProcurarInstancia() {
    global buscaAtiva, buscaOcupada, subindo, erroImagem, txtBusca, btnBusca, editNome, erroNome
    global ciclosSemVaga, inicioBusca, tempoPainelMs, tempoVagaMs, posicaoBusca
    global modoFundo
    if !buscaAtiva || buscaOcupada
        return
    buscaOcupada := true
    intervaloProximo := 10
    try {
        if !IsObject(posicaoBusca) {
            ; Esta preparacao so ocorre no primeiro ciclo apos o F12.
            hwnd := modoFundo ? EncontrarPKA() : AtivarPKA()
            if !hwnd {
                txtBusca.Text := "Status: aguardando a janela do PKA"
                intervaloProximo := 1000
                return
            }
            if !CapturarBusca(hwnd) {
                txtBusca.Text := "Status: aguardando captura do PKA"
                intervaloProximo := 800
                return
            }
            nome := Trim(editNome.Value)
            posicaoEncontrada := ObterPosicaoCalibrada(hwnd, nome, &px, &py)
            if !posicaoEncontrada {
                posicaoEncontrada := LocalizarNomePersonagem(hwnd, nome, &px, &py)
                if posicaoEncontrada
                    SalvarCalibracao(hwnd, nome, px, py, &erroSalvar)
            }
            painelAberto := LocalizarJanelaConhecida(hwnd, &mx, &my, &escalaUI)
            if !posicaoEncontrada && painelAberto {
                txtBusca.Text := "Status: nome oculto; tentando novamente"
                FecharPainelBusca(hwnd)
                intervaloProximo := 300
                return
            }
            if !painelAberto {
                if !posicaoEncontrada {
                    txtBusca.Text := "Status: " erroNome " (tentando novamente)"
                    intervaloProximo := 1000
                    return
                }
                ClicarBusca(hwnd, px, py, "Right")
                if !modoFundo
                    Sleep 60
                if !buscaAtiva
                    return
                if !CapturarBusca(hwnd) {
                    txtBusca.Text := "Status: aguardando captura do painel"
                    intervaloProximo := 500
                    return
                }
                if !LocalizarJanelaInstancia(hwnd, &mx, &my, &escalaUI) {
                    Sleep 60
                    CapturarBusca(hwnd)
                    if !LocalizarJanelaInstancia(hwnd, &mx, &my, &escalaUI) {
                        txtBusca.Text := "Status: aguardando janela de instâncias"
                        FecharPainelBusca(hwnd)
                        intervaloProximo := 300
                        return
                    }
                }
            }
            if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch) {
                txtBusca.Text := "Status: aguardando área do jogo"
                intervaloProximo := 500
                return
            }
            posicaoBusca := {hwnd: hwnd, px: px, py: py, mx: mx, my: my,
                escala: escalaUI, cx: cx, cy: cy, cw: cw, ch: ch}
            tempoPainelMs := A_TickCount - inicioBusca
        } else {
            ; Reabre diretamente pelo SQM salvo, sem OCR nem varredura
            ; para achar novamente o painel.
            hwnd := posicaoBusca.hwnd
            if !(modoFundo ? WinExist("ahk_id " hwnd) : AtivarJanelaDaBusca(hwnd)) {
                txtBusca.Text := "Status: aguardando o PKA voltar"
                intervaloProximo := 1000
                return
            }
            ClicarBusca(hwnd, posicaoBusca.px, posicaoBusca.py, "Right")
            if !modoFundo
                Sleep 60
            if !CapturarBusca(hwnd) {
                txtBusca.Text := "Status: aguardando captura do PKA"
                intervaloProximo := 800
                return
            }
            if !PainelAbertoNaPosicao(posicaoBusca) {
                Sleep 60
                CapturarBusca(hwnd)
                if !PainelAbertoNaPosicao(posicaoBusca) {
                    txtBusca.Text := "Status: painel não confirmado; tentando novamente"
                    FecharPainelBusca(hwnd)
                    intervaloProximo := 120
                    return
                }
            }
            mx := posicaoBusca.mx
            my := posicaoBusca.my
            escalaUI := posicaoBusca.escala
        }
        if !CapturarListaNaBarra(hwnd, mx, my, escalaUI) {
            txtBusca.Text := "Status: aguardando captura da lista"
            intervaloProximo := 800
            return
        }
        inicioImagem := A_TickCount
        ; Busca ampla apenas na primeira tela apos F12. As demais usam
        ; a coluna dos contadores, inclusive apos cada passo do scroll.
        rapido := ciclosSemVaga > 0
        if ProcurarZero(posicaoBusca, mx, my, escalaUI, &x, &y, &fator, rapido) {
            tempoVagaMs := A_TickCount - inicioImagem
            EntrarInstancia(hwnd, mx, my, escalaUI, y, fator)
            return
        }
        if erroImagem {
            txtBusca.Text := "Status: falha na imagem; tentando novamente"
            FecharPainelBusca(hwnd)
            intervaloProximo := 1000
            return
        }
        Loop 7 {
            if !buscaAtiva
                return
            if !RolarLista(hwnd, mx, my, escalaUI, subindo ? "Up" : "Down", 1) {
                txtBusca.Text := "Status: aguardando captura da lista"
                intervaloProximo := 800
                return
            }
            if ProcurarZero(posicaoBusca, mx, my, escalaUI, &x, &y, &fator, true) {
                tempoVagaMs := A_TickCount - inicioImagem
                EntrarInstancia(hwnd, mx, my, escalaUI, y, fator)
                return
            }
            if erroImagem {
                txtBusca.Text := "Status: falha na imagem; tentando novamente"
                FecharPainelBusca(hwnd)
                intervaloProximo := 1000
                return
            }
        }
        subindo := !subindo
        ciclosSemVaga++
        FecharPainelBusca(hwnd)
        Sleep 20
        txtBusca.Text := "Status: sem vaga | ciclo " ciclosSemVaga " em " Round((A_TickCount - inicioImagem) / 1000, 2) "s"
    } catch as erro {
        txtBusca.Text := "Status: falha temporária; tentando novamente (" erro.Message ")"
        intervaloProximo := 500
    } finally {
        buscaOcupada := false
        if buscaAtiva
            SetTimer ProcurarInstancia, -intervaloProximo
        else {
            SetTimer EncontrarPKA, 2000
            btnBusca.Text := "Iniciar busca (F12)"
        }
    }
}

CapturarListaNaBarra(hwnd, mx, my, escalaUI) {
    global modoFundo
    ; A barra nao abre descricoes sobre o texto "0 jogadores".
    x := Round(mx + 293 * escalaUI)
    y := Round(my)
    if modoFundo {
        if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
            throw Error("Área do jogo indisponível")
        rx := Round(x - cx)
        ry := Round(y - cy)
        PostMessage 0x0200, 0, (rx & 0xFFFF) | ((ry & 0xFFFF) << 16), , "ahk_id " hwnd
    } else
        MouseMove x, y, 0
    Sleep 35
    return CapturarBusca(hwnd)
}

RolarLista(hwnd, mx, my, escalaUI, sentido, qtd) {
    global modoFundo, imagemTela, telaCx, telaCy, telaSx, telaSy
    x := Round(mx + 293 * escalaUI)
    y := Round(my)
    if modoFundo {
        if !ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch)
            throw Error("Área do jogo indisponível")
        rx := Round(x - cx)
        ry := Round(y - cy)
        PostMessage 0x0200, 0, (rx & 0xFFFF) | ((ry & 0xFFFF) << 16), , "ahk_id " hwnd
        imagemAnterior := imagemTela
    } else
        MouseMove x, y, 0
    Sleep 20
    Loop qtd {
        if modoFundo {
            delta := sentido = "Up" ? 120 : -120
            PostMessage 0x020A, (delta & 0xFFFF) << 16,
                (x & 0xFFFF) | ((y & 0xFFFF) << 16), , "ahk_id " hwnd
        } else
            Send sentido = "Up" ? "{WheelUp}" : "{WheelDown}"
        Sleep 6
    }
    Sleep modoFundo ? 30 : 70
    if !CapturarBusca(hwnd)
        return false
    if modoFundo && !BarraRolou(imagemAnterior, imagemTela, x, my, escalaUI,
        telaCx, telaCy, telaSx, telaSy) {
        ; Reenvia pela alternativa sem mudar a posicao real do cursor.
        ControlClick("x" rx " y" ry, "ahk_id " hwnd, "",
            sentido = "Up" ? "WheelUp" : "WheelDown", qtd, "NA Pos")
        Sleep 30
        return CapturarBusca(hwnd)
    }
    return true
}

BarraRolou(antes, depois, x, my, escalaUI, cx, cy, sx, sy) {
    if !IsObject(antes) || !IsObject(depois)
        return false
    if antes.width != depois.width || antes.height != depois.height
        return true
    topo := Round((my - 100 * escalaUI - cy) * sy)
    fundo := Round((my + 125 * escalaUI - cy) * sy)
    mudancas := 0
    for deslocamento in [-3, 0, 3] {
        coluna := Round((x + deslocamento * escalaUI - cx) * sx)
        if coluna < 0 || coluna >= depois.width
            continue
        linha := Max(0, topo)
        while linha <= Min(depois.height - 1, fundo) {
            corAntes := antes[coluna, linha] & 0xFFFFFF
            corDepois := depois[coluna, linha] & 0xFFFFFF
            diferenca := Abs(((corAntes >> 16) & 255) - ((corDepois >> 16) & 255))
                + Abs(((corAntes >> 8) & 255) - ((corDepois >> 8) & 255))
                + Abs((corAntes & 255) - (corDepois & 255))
            if diferenca > 90
                mudancas++
            linha += 3
        }
    }
    return mudancas >= 12
}

EntrarInstancia(hwnd, mx, my, escalaUI, y, fatorImagem) {
    global buscaAtiva, btnBusca, txtBusca, inicioBusca, tempoPainelMs, tempoVagaMs
    global modoFundo, posicaoBusca
    SetTimer ProcurarInstancia, 0
    ClicarBusca(hwnd, Round(mx + 40 * escalaUI), Round(y + 15 * fatorImagem))
    Sleep 50
    if !buscaAtiva
        return
    ClicarBusca(hwnd, Round(mx + 219 * escalaUI), Round(my + 156 * escalaUI))
    if modoFundo {
        Sleep 120
        if !CapturarBusca(hwnd) || PainelAbertoNaPosicao(posicaoBusca) {
            ; Segunda tentativa sem ocupar o mouse. O foco so e usado
            ; se o cliente ignorar tambem os cliques diretos.
            if ObterAreaCliente(hwnd, &cx, &cy, &cw, &ch) {
                rxLinha := Round(mx + 40 * escalaUI - cx)
                ryLinha := Round(y + 15 * fatorImagem - cy)
                rxEntrar := Round(mx + 219 * escalaUI - cx)
                ryEntrar := Round(my + 156 * escalaUI - cy)
                ControlClick("x" rxLinha " y" ryLinha, "ahk_id " hwnd, "", "Left", 1, "NA Pos")
                Sleep 50
                ControlClick("x" rxEntrar " y" ryEntrar, "ahk_id " hwnd, "", "Left", 1, "NA Pos")
                Sleep 120
            }
            if !CapturarBusca(hwnd) || PainelAbertoNaPosicao(posicaoBusca) {
                ; Ultimo recurso: foco e clique real somente depois de
                ; encontrada a vaga, nunca durante a varredura.
                if AtivarJanelaDaBusca(hwnd) {
                    MouseMove Round(mx + 40 * escalaUI), Round(y + 15 * fatorImagem), 0
                    Click "Left"
                    Sleep 50
                    Click Round(mx + 219 * escalaUI), Round(my + 156 * escalaUI)
                }
            }
        }
        Sleep 80
        if !CapturarBusca(hwnd) {
            posicaoBusca := 0
            txtBusca.Text := "Status: verificando entrada; tentando novamente"
            return
        }
        if PainelAbertoNaPosicao(posicaoBusca) {
            FecharPainelBusca(hwnd)
            posicaoBusca := 0
            txtBusca.Text := "Status: entrada não confirmada; buscando novamente"
            return
        }
    }
    SetTimer ApitarTresVezes, -1
    buscaAtiva := false
    btnBusca.Text := "Iniciar busca (F12)"
    duracao := Round((A_TickCount - inicioBusca) / 1000, 1)
    txtBusca.Text := "Entrada " duracao "s | janela " Round(tempoPainelMs / 1000, 1) "s | vaga " Round(tempoVagaMs / 1000, 1) "s"
}

ApitarTresVezes() {
    Loop 3 {
        SoundBeep 880, 140
        Sleep 90
    }
}
