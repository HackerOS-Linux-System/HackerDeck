package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/diamondburned/gotk4-adwaita/pkg/adw"
	"github.com/diamondburned/gotk4/pkg/cairo"
	"github.com/diamondburned/gotk4/pkg/core/glib"
	"github.com/diamondburned/gotk4/pkg/gdk/v4"
	"github.com/diamondburned/gotk4/pkg/gtk/v4"
)

const (
	appID       = "com.hackerdeck.HackerDeck"
	configDir   = "$HOME/.config/hackerdeck"
	instancesDB = "instances.json"
	keymapFile  = "keymaps.json"
)

var (
	window             *adw.ApplicationWindow
	statusLabel        *gtk.Label
	logBuffer          *gtk.TextBuffer
	appListBox         *gtk.ListBox
	overlayWindow      *gtk.Window
	overlayDrawingArea *gtk.DrawingArea
	mouseSteering      bool
	lastMouseX         float64
	lastMouseY         float64
	keyMappings        []KeyMapping
	keyMutex           sync.Mutex
	instances          []Instance
	currentInstance    int
	circles            []KeyCircle
	draggingIndex      = -1
)

type KeyMapping struct {
	Key  string  `json:"key"`
	Type string  `json:"type"` // "tap" lub "keyevent"
	X    float64 `json:"x"`
	Y    float64 `json:"y"`
	Code int     `json:"code,omitempty"`
}

type Instance struct {
	Name    string `json:"name"`
	DataDir string `json:"data_dir"`
}

type KeyCircle struct {
	Key    string
	X      float64
	Y      float64
	Radius float64
}

func main() {
	app := adw.NewApplication(appID, 0)
	app.ConnectActivate(onActivate)
	app.Run(os.Args)
}

func onActivate(app *adw.Application) {
	adw.Init()
	window = adw.NewApplicationWindow(app)
	window.SetTitle("HackerDeck v3.0")
	window.SetDefaultSize(1300, 850)

	header := adw.NewHeaderBar()
	title := adw.NewWindowTitle("HackerDeck", "BlueStacks Killer • Multi-Instance • Visual Keymapper")
	header.SetTitleWidget(title.Widget())

	toastOverlay := adw.NewToastOverlay()
	toastOverlay.SetChild(createMainUI())

	window.SetContent(toastOverlay)
	window.Show()

	loadInstances()
	loadKeyMappings()
	go periodicStatus()

	controller := gtk.NewEventControllerKey()
	controller.ConnectKeyPressed(onGlobalKeyPressed)
	window.AddController(controller)

	if !isWaydroidInstalled() {
		showFirstRun()
	} else {
		go refreshAppList()
	}
}

func createMainUI() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 0)

	statusBox := gtk.NewBox(gtk.OrientationHorizontal, 8)
	statusBox.SetMargin(12)
	statusLabel = gtk.NewLabel("HackerDeck v3.0 gotowy")
	statusBox.Append(statusLabel)
	box.Append(statusBox)

	notebook := gtk.NewNotebook()

	notebook.AppendPage(createStatusPage(), gtk.NewLabel("Status"))
	notebook.AppendPage(createAppsPage(), gtk.NewLabel("Aplikacje"))
	notebook.AppendPage(createInstancesPage(), gtk.NewLabel("Instancje"))
	notebook.AppendPage(createVisualKeymapperPage(), gtk.NewLabel("Visual Keymapper"))
	notebook.AppendPage(createMouseSteeringPage(), gtk.NewLabel("Mouse Steering (FPS)"))
	notebook.AppendPage(createToolsPage(), gtk.NewLabel("Narzędzia"))

	box.Append(notebook)

	logScroll := gtk.NewScrolledWindow()
	logScroll.SetVexpand(true)
	logView := gtk.NewTextView()
	logView.SetEditable(false)
	logBuffer = logView.Buffer()
	logScroll.SetChild(logView)
	box.Append(logScroll)

	return box
}

// ==================== STATUS PAGE ====================
func createStatusPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 12)
	box.SetMargin(20)

	btns := [][]string{
		{"▶ Start kontenera", "waydroid", "container", "start"},
		{"▶ Start sesji", "waydroid", "session", "start"},
		{"📺 Pełny interfejs", "waydroid", "show-full-ui"},
		{"⏹ Zatrzymaj wszystko", "waydroid", "session", "stop"},
	}

	for _, b := range btns {
		btn := gtk.NewButtonWithLabel(b[0])
		cmd := b[1:]
		btn.ConnectClicked(func() { runCommand(cmd, true) })
		box.Append(btn)
	}
	return box
}

// ==================== APLIKACJE PAGE (pełne z ikonami) ====================
func createAppsPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 6)
	box.SetMargin(12)

	toolbar := gtk.NewBox(gtk.OrientationHorizontal, 8)
	refreshBtn := gtk.NewButtonWithLabel("Odśwież listę")
	installBtn := gtk.NewButtonWithLabel("📦 Zainstaluj APK")
	refreshBtn.ConnectClicked(refreshAppList)
	installBtn.ConnectClicked(installAPKDialog)
	toolbar.Append(refreshBtn)
	toolbar.Append(installBtn)
	box.Append(toolbar)

	appListBox = gtk.NewListBox()
	appListBox.SetSelectionMode(gtk.SelectionNone)
	scroll := gtk.NewScrolledWindow()
	scroll.SetVexpand(true)
	scroll.SetChild(appListBox)
	box.Append(scroll)
	return box
}

func refreshAppList() {
	appListBox.RemoveAll()

	out, _ := exec.Command("waydroid", "app", "list").Output()
	lines := strings.Split(string(out), "\n")

	var current App
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Name:") {
			current.Name = strings.TrimPrefix(line, "Name:")
			current.Name = strings.TrimSpace(current.Name)
		} else if strings.HasPrefix(line, "Package:") {
			current.Package = strings.TrimPrefix(line, "Package:")
			current.Package = strings.TrimSpace(current.Package)
			current.Icon = getAppIcon(current.Package)

			row := createAppRow(current)
			appListBox.Append(row)
			current = App{}
		}
	}
}

type App struct {
	Name    string
	Package string
	Icon    string
}

func getAppIcon(pkg string) string {
	cmd := exec.Command("sh", "-c", fmt.Sprintf(`find /var/lib/waydroid/overlay -name "*.png" -path "*/%s*" | head -1`, pkg))
	if out, err := cmd.Output(); err == nil && len(out) > 0 {
		return strings.TrimSpace(string(out))
	}
	return ""
}

func createAppRow(app App) gtk.Widgetter {
	row := gtk.NewListBoxRow()
	box := gtk.NewBox(gtk.OrientationHorizontal, 12)
	box.SetMargin(12)

	var iconWidget gtk.Widgetter
	if app.Icon != "" {
		img := gtk.NewImageFromFile(app.Icon)
		img.SetSizeRequest(48, 48)
		iconWidget = img
	} else {
		img := gtk.NewImageFromIconName("android")
		img.SetPixelSize(48)
		iconWidget = img
	}
	box.Append(iconWidget)

	vbox := gtk.NewBox(gtk.OrientationVertical, 2)
	nameLabel := gtk.NewLabel("<b>" + app.Name + "</b>")
	nameLabel.SetUseMarkup(true)
	nameLabel.SetXalign(0)
	pkgLabel := gtk.NewLabel(app.Package)
	pkgLabel.SetXalign(0)
	vbox.Append(nameLabel)
	vbox.Append(pkgLabel)
	box.Append(vbox)

	launchBtn := gtk.NewButtonWithLabel("Uruchom")
	launchBtn.ConnectClicked(func() {
		runCommand([]string{"waydroid", "app", "launch", app.Package}, false)
	})
	box.Append(launchBtn)

	row.SetChild(box)
	return row
}

func installAPKDialog() {
	dialog := gtk.NewFileChooserDialog("Wybierz plik .apk", window, gtk.FileChooserActionOpen)
	dialog.AddButton("Anuluj", gtk.ResponseCancel)
	dialog.AddButton("Zainstaluj", gtk.ResponseAccept)
	dialog.ConnectResponse(func(resp int) {
		if resp == gtk.ResponseAccept {
			if f := dialog.File(); f != nil {
				runCommand([]string{"waydroid", "app", "install", f.Path()}, false)
				glib.TimeoutAdd(2000, func() bool {
					refreshAppList()
					return false
				})
			}
		}
		dialog.Destroy()
	})
	dialog.Show()
}

// ==================== INSTANCJE PAGE ====================
func createInstancesPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 12)
	box.SetMargin(20)

	list := gtk.NewListBox()
	scroll := gtk.NewScrolledWindow()
	scroll.SetVexpand(true)
	scroll.SetChild(list)
	box.Append(scroll)

	refreshInstancesList(list)

	newBtn := gtk.NewButtonWithLabel("➕ Nowa instancja")
	newBtn.ConnectClicked(createNewInstanceDialog)
	box.Append(newBtn)

	return box
}

func refreshInstancesList(list *gtk.ListBox) {
	list.RemoveAll()
	for i, inst := range instances {
		row := gtk.NewListBoxRow()
		b := gtk.NewBox(gtk.OrientationHorizontal, 12)
		b.SetMargin(10)

		lbl := gtk.NewLabel(inst.Name)
		if i == currentInstance {
			lbl.SetMarkup("<b>" + inst.Name + " (aktywna)</b>")
		}
		b.Append(lbl)

		switchBtn := gtk.NewButtonWithLabel("Przełącz")
		switchBtn.ConnectClicked(func() {
			currentInstance = i
			log("Przełączono na instancję: " + inst.Name)
			refreshInstancesList(list)
			updateStatus()
		})
		b.Append(switchBtn)

		row.SetChild(b)
		list.Append(row)
	}
}

func createNewInstanceDialog() {
	dialog := adw.NewDialog()
	dialog.SetTitle("Nowa instancja")
	content := gtk.NewBox(gtk.OrientationVertical, 12)
	content.SetMargin(20)

	entry := gtk.NewEntry()
	entry.SetPlaceholderText("Nazwa (np. PUBG)")
	content.Append(entry)

	saveBtn := gtk.NewButtonWithLabel("Utwórz")
	saveBtn.ConnectClicked(func() {
		name := strings.TrimSpace(entry.Text())
		if name == "" {
			return
		}
		dataDir := fmt.Sprintf("/var/lib/waydroid_instance_%d", len(instances))
		runCommand([]string{"pkexec", "mkdir", "-p", dataDir}, true)
		runCommand([]string{"pkexec", "cp", "-r", "/var/lib/waydroid", dataDir}, true)
		instances = append(instances, Instance{Name: name, DataDir: dataDir})
		saveInstances()
		dialog.Close()
		refreshInstancesList(nil)
	})
	content.Append(saveBtn)
	dialog.SetContent(content)
	dialog.Show()
}

func saveInstances() {
	path := filepath.Join(os.ExpandEnv(configDir), instancesDB)
	data, _ := json.MarshalIndent(instances, "", "  ")
	os.WriteFile(path, data, 0644)
}

func loadInstances() {
	path := filepath.Join(os.ExpandEnv(configDir), instancesDB)
	data, err := os.ReadFile(path)
	if err != nil {
		instances = []Instance{{Name: "Domyślna", DataDir: "/var/lib/waydroid"}}
		return
	}
	json.Unmarshal(data, &instances)
}

// ==================== VISUAL KEYMAPPER PAGE ====================
func createVisualKeymapperPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 12)
	box.SetMargin(20)

	openBtn := gtk.NewButtonWithLabel("🚀 Otwórz Visual Overlay (przezroczyste okno nad Waydroid)")
	openBtn.ConnectClicked(openVisualOverlay)
	box.Append(openBtn)

	info := gtk.NewLabel("Kliknij w dowolne miejsce → podaj klawisz.\nKółka można przeciągać myszką.\nOkno dopasuj nad pełnym UI Waydroid.")
	info.SetWrap(true)
	box.Append(info)

	return box
}

func openVisualOverlay() {
	if overlayWindow != nil {
		overlayWindow.Present()
		return
	}

	overlayWindow = gtk.NewWindow()
	overlayWindow.SetTitle("HackerDeck Visual Keymapper Overlay")
	overlayWindow.SetDefaultSize(720, 1280)
	overlayWindow.SetOpacity(0.35)
	overlayWindow.SetDecorated(false)
	overlayWindow.SetResizable(true)

	da := gtk.NewDrawingArea()
	da.SetDrawFunc(drawOverlay)
	da.SetSizeRequest(720, 1280)
	overlayDrawingArea = da

	// Kliknięcie – dodaj nowe lub przeciągaj
	click := gtk.NewGestureClick()
	click.ConnectPressed(func(nPress int, x, y float64) {
		for i := range circles {
			if math.Hypot(x-circles[i].X, y-circles[i].Y) < circles[i].Radius {
				draggingIndex = i
				return
			}
		}
		showKeyNameDialog(x, y)
	})
	da.AddController(click)

	// Przeciąganie
	drag := gtk.NewGestureDrag()
	drag.ConnectDragBegin(func(x, y float64) {
		for i := range circles {
			if math.Hypot(x-circles[i].X, y-circles[i].Y) < circles[i].Radius {
				draggingIndex = i
				break
			}
		}
	})
	drag.ConnectDragUpdate(func(offsetX, offsetY float64) {
		if draggingIndex != -1 {
			circles[draggingIndex].X += offsetX
			circles[draggingIndex].Y += offsetY
			da.QueueDraw()
		}
	})
	drag.ConnectDragEnd(func() {
		if draggingIndex != -1 {
			saveVisualKeymap()
			draggingIndex = -1
		}
	})
	da.AddController(drag)

	overlayWindow.SetChild(da)
	overlayWindow.ConnectDestroy(func() {
		overlayWindow = nil
		overlayDrawingArea = nil
	})

	// Załaduj istniejące kółka
	if len(circles) == 0 {
		keyMutex.Lock()
		for _, m := range keyMappings {
			if m.Type == "tap" {
				circles = append(circles, KeyCircle{Key: m.Key, X: m.X, Y: m.Y, Radius: 35})
			}
		}
		keyMutex.Unlock()
	}

	overlayWindow.Show()
}

func drawOverlay(_ *gtk.DrawingArea, cr *cairo.Context, _, _ int) {
	cr.SetSourceRGBA(0, 0.8, 1, 0.9)
	for _, c := range circles {
		cr.Arc(c.X, c.Y, c.Radius, 0, 2*math.Pi)
		cr.Fill()

		cr.SetSourceRGB(1, 1, 1)
		cr.SetFontSize(28)
		cr.MoveTo(c.X-12, c.Y+10)
		cr.ShowText(strings.ToUpper(c.Key))
	}
}

func showKeyNameDialog(x, y float64) {
	dialog := gtk.NewDialogWithButtons("Nowy klawisz", window, gtk.DialogFlagsModal,
		[]string{"Anuluj", "Zapisz"}, []int{gtk.ResponseCancel, gtk.ResponseOK})

	entry := gtk.NewEntry()
	entry.SetPlaceholderText("w / a / s / d / space / f1 ...")
	dialog.SetChild(entry)

	dialog.ConnectResponse(func(resp int) {
		if resp == gtk.ResponseOK {
			key := strings.TrimSpace(entry.Text())
			if key != "" {
				circles = append(circles, KeyCircle{Key: key, X: x, Y: y, Radius: 35})
				saveVisualKeymap()
				if overlayDrawingArea != nil {
					overlayDrawingArea.QueueDraw()
				}
			}
		}
		dialog.Destroy()
	})
	dialog.Show()
}

func saveVisualKeymap() {
	keyMutex.Lock()
	keyMappings = []KeyMapping{}
	for _, c := range circles {
		keyMappings = append(keyMappings, KeyMapping{
			Key:  c.Key,
			Type: "tap",
			X:    c.X,
			Y:    c.Y,
		})
	}
	keyMutex.Unlock()
	saveKeyMappings()
}

// ==================== MOUSE STEERING PAGE ====================
func createMouseSteeringPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 12)
	box.SetMargin(20)

	lbl := gtk.NewLabel("F1 = włącz/wyłącz tryb FPS\nRuch myszy = spojrzenie kamerą (PUBG, Free Fire)")
	lbl.SetWrap(true)
	box.Append(lbl)

	toggle := gtk.NewSwitch()
	toggle.SetActive(mouseSteering)
	toggle.ConnectStateSet(func(active bool) bool {
		mouseSteering = active
		if active {
			startMouseSteering()
		} else {
			stopMouseSteering()
		}
		return false
	})
	box.Append(toggle)
	return box
}

func startMouseSteering() {
	log("🎮 Mouse Steering AKTYWNY (F1 do wyłączenia)")
	seat := gdk.DisplayGetDefault().DefaultSeat()
	seat.Grab(window.Surface(), gdk.SeatCapabilityPointer, true, nil, nil, nil)

	motion := gtk.NewEventControllerMotion()
	motion.ConnectMotion(func(x, y float64) {
		if !mouseSteering {
			return
		}
		dx := x - lastMouseX
		dy := y - lastMouseY
		lastMouseX = x
		lastMouseY = y

		centerX := 360
		centerY := 640
		runCommand([]string{"waydroid", "shell", "input", "touchscreen", "swipe",
			strconv.Itoa(centerX), strconv.Itoa(centerY),
			strconv.Itoa(centerX+int(dx*2.5)), strconv.Itoa(centerY+int(dy*2.5)), "80"}, false)
	})
	window.AddController(motion)

	window.SetCursor(gdk.NewCursorFromName("none"))
}

func stopMouseSteering() {
	window.SetCursor(nil)
	log("Mouse Steering wyłączony")
}

// ==================== GLOBAL KEY HANDLER ====================
func onGlobalKeyPressed(keyval uint, _ uint, _ gdk.ModifierType) bool {
	if keyval == gdk.KEY_F1 {
		mouseSteering = !mouseSteering
		if mouseSteering {
			startMouseSteering()
		} else {
			stopMouseSteering()
		}
		return true
	}
	// Keyboard tap z keyMappings (działa równolegle z overlay)
	keyMutex.Lock()
	keyName := strings.ToLower(gdk.KeyvalName(keyval))
	for _, m := range keyMappings {
		if m.Key == keyName && m.Type == "tap" {
			runCommand([]string{"waydroid", "shell", "input", "tap",
				strconv.FormatFloat(m.X, 'f', 0, 64),
				strconv.FormatFloat(m.Y, 'f', 0, 64)}, false)
			keyMutex.Unlock()
			return false
		}
	}
	keyMutex.Unlock()
	return false
}

// ==================== TOOLS PAGE + FULL INSTALLER ====================
func createToolsPage() gtk.Widgetter {
	box := gtk.NewBox(gtk.OrientationVertical, 12)
	box.SetMargin(20)

	if !isWaydroidInstalled() {
		installBtn := gtk.NewButtonWithLabel("🚀 Zainstaluj Waydroid + GAPPS (pierwsze uruchomienie)")
		installBtn.ConnectClicked(fullInstaller)
		box.Append(installBtn)
		return box
	}

	initBtn := gtk.NewButtonWithLabel("🔄 Reinicjalizuj Waydroid (najnowszy Android + Play Store)")
	initBtn.ConnectClicked(func() {
		runCommand([]string{"waydroid", "init", "-s", "GAPPS"}, false)
	})
	box.Append(initBtn)
	return box
}

func fullInstaller() {
	log("=== ROZPOCZYNAM INSTALACJĘ HACKERDECK ===")
	runCommand([]string{"pkexec", "apt", "update"}, true)
	runCommand([]string{"pkexec", "apt", "install", "-y", "curl", "ca-certificates"}, true)
	runCommand([]string{"pkexec", "bash", "-c", `curl -s https://repo.waydro.id | bash`}, true)
	runCommand([]string{"pkexec", "apt", "install", "-y", "waydroid"}, true)
	runCommand([]string{"waydroid", "init", "-s", "GAPPS"}, false)
	markAsInstalled()
	log("🎉 Instalacja zakończona! Uruchom ponownie HackerDeck.")
}

// ==================== RUN COMMAND (pkexec + multi-instance) ====================
func runCommand(args []string, needsRoot bool) {
	go func() {
		var cmd *exec.Cmd
		if needsRoot {
			cmd = exec.Command("pkexec", args...)
		} else {
			cmd = exec.Command(args[0], args[1:]...)
		}

		if currentInstance < len(instances) && instances[currentInstance].DataDir != "/var/lib/waydroid" {
			cmd.Env = append(os.Environ(), "WAYDROID_DATA="+instances[currentInstance].DataDir)
		}

		stdout, _ := cmd.StdoutPipe()
		log("🚀 " + strings.Join(args, " "))
		cmd.Start()

		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			log(scanner.Text())
		}
		cmd.Wait()
		glib.IdleAdd(func() {
			updateStatus()
			refreshAppList()
		})
	}()
}

// ==================== CONFIG + STATUS ====================
func loadKeyMappings() {
	path := filepath.Join(os.ExpandEnv(configDir), keymapFile)
	data, err := os.ReadFile(path)
	if err != nil {
		keyMappings = []KeyMapping{
			{Key: "w", Type: "tap", X: 500, Y: 300},
			{Key: "s", Type: "tap", X: 500, Y: 700},
			{Key: "a", Type: "tap", X: 300, Y: 500},
			{Key: "d", Type: "tap", X: 700, Y: 500},
		}
		saveKeyMappings()
		return
	}
	json.Unmarshal(data, &keyMappings)
}

func saveKeyMappings() {
	path := filepath.Join(os.ExpandEnv(configDir), keymapFile)
	data, _ := json.MarshalIndent(keyMappings, "", "  ")
	os.WriteFile(path, data, 0644)
}

func isWaydroidInstalled() bool {
	_, err := exec.LookPath("waydroid")
	return err == nil
}

func markAsInstalled() {
	os.MkdirAll(os.ExpandEnv(configDir), 0755)
	os.WriteFile(filepath.Join(os.ExpandEnv(configDir), "installed"), []byte("1"), 0644)
}

func log(msg string) {
	glib.IdleAdd(func() {
		logBuffer.Insert(logBuffer.GetEndIter(), msg+"\n")
	})
}

func updateStatus() {
	out, _ := exec.Command("waydroid", "status").Output()
	statusLabel.SetLabel("Instancja: " + instances[currentInstance].Name + " | " + strings.TrimSpace(string(out)))
}

func periodicStatus() {
	for range time.Tick(5 * time.Second) {
		glib.IdleAdd(updateStatus)
	}
}

func showFirstRun() {
	log("🔴 PIERWSZE URUCHOMIENIE – przejdź do zakładki Narzędzia i kliknij instalację")
}
