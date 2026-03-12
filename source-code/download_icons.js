const https = require('https');
const fs = require('fs');
const path = require('path');

const dir = path.join(process.cwd(), 'src-tauri', 'icons');
fs.mkdirSync(dir, { recursive: true });

const download = (url, dest) => {
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(dest);
        https.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`Failed to get '${url}' (${response.statusCode})`));
                return;
            }
            response.pipe(file);
            file.on('finish', () => {
                file.close(resolve);
            });
        }).on('error', (err) => {
            fs.unlink(dest, () => reject(err));
        });
    });
};

async function run() {
    try {
        const baseUrl = "https://raw.githubusercontent.com/tauri-apps/tauri/1.x/tooling/cli/templates/app/src-tauri/icons";
        console.log("Pobieranie ikon...");
        await download(`${baseUrl}/icon.png`, path.join(dir, 'icon.png'));
        await download(`${baseUrl}/32x32.png`, path.join(dir, '32x32.png'));
        await download(`${baseUrl}/128x128.png`, path.join(dir, '128x128.png'));
        await download(`${baseUrl}/128x128@2x.png`, path.join(dir, '128x128@2x.png'));
        await download(`${baseUrl}/icon.ico`, path.join(dir, 'icon.ico'));
        await download(`${baseUrl}/icon.icns`, path.join(dir, 'icon.icns'));
        console.log("Ikony zostały pomyślnie pobrane i zapisane w src-tauri/icons/");
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

run();
