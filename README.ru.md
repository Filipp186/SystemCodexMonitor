# System & Codex Monitor

[![Build](https://github.com/Filipp186/SystemCodexMonitor/actions/workflows/build.yml/badge.svg)](https://github.com/Filipp186/SystemCodexMonitor/actions/workflows/build.yml)

[English](README.md)

Неофициальное расширение для панели Microsoft PowerToys Command Palette. Оно компактно показывает восемь параметров под четырьмя значками:

- оставшийся лимит Codex;
- температуру и загрузку CPU;
- температуру модулей RAM и загрузку физической памяти;
- температуру, загрузку GPU и занятую видеопамять.

Значения отображаются в одну строку. При наведении видны подписи, подробности и время сброса лимита Codex.

## Требования

- Windows 11 x64;
- PowerToys Command Palette с поддержкой Dock;
- включённый режим разработчика Windows для установки из ZIP;
- запущенная AIDA64 с настройкой **Настройки → Внешние приложения → Разрешить общую память**;
- установленный и авторизованный Codex CLI (`codex.exe`).

Температуры CPU, RAM и GPU читаются из Shared Memory AIDA64. Загрузка оборудования читается через LibreHardwareMonitor. Лимиты Codex запрашиваются локально через `codex app-server`; расширение не читает и не сохраняет токены аккаунта.

## Установка

1. Скачайте `SystemCodexMonitor-v0.1.2-win-x64.zip` на странице [Releases](https://github.com/Filipp186/SystemCodexMonitor/releases/latest).
2. Распакуйте архив.
3. Запустите `Install.cmd`.
4. В настройках Command Palette включите **System & Codex Monitor**, затем добавьте в Dock полосы **System sensors** и **Codex limit**.
5. В режиме редактирования Dock отключите субтитры, чтобы оставить компактную строку.

Установщик копирует приложение в `%LOCALAPPDATA%\Programs\SystemCodexMonitor`. После установки распакованный архив можно удалить.

Для удаления запустите `Uninstall.cmd` из архива релиза.

## Сборка

Нужны .NET 10 SDK и Windows SDK 10.0.26100.

```powershell
dotnet restore SystemCodexMonitor.sln
dotnet build SystemCodexMonitor.sln -c Release -p:Platform=x64
```

Создание ZIP-релиза:

```powershell
.\scripts\New-Release.ps1 -Version 0.1.2
```

## Примечания

- Аппаратные показатели обновляются раз в две секунды, лимит Codex — раз в две минуты.
- Для отображения температур CPU и RAM AIDA64 должна оставаться запущенной.
- Проект не связан с Microsoft, FinalWire или OpenAI.
- Названия и знаки OpenAI и Codex принадлежат OpenAI и не распространяются под лицензией MIT этого репозитория.

Лицензии зависимостей перечислены в [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
