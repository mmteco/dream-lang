// Dream Language Extension for VSCode
const vscode = require('vscode');
const path = require('path');
const { execSync } = require('child_process');

// 文档符号缓存
const documentSymbols = new Map();

// 调用 dream lsp 命令获取符号信息
function analyzeDreamFile(filePath) {
  try {
    // 查找 dream 可执行文件
    const dreamPath = findDreamExecutable();
    if (!dreamPath) {
      console.error('Dream compiler not found');
      return null;
    }

    // 执行 dream lsp 命令
    const output = execSync(`${dreamPath} lsp "${filePath}"`, {
      encoding: 'utf-8',
      timeout: 5000
    });

    // 解析 JSON 输出
    const result = JSON.parse(output);
    return result;
  } catch (error) {
    console.error('Failed to analyze Dream file:', error);
    return null;
  }
}

// 查找 dream 可执行文件
function findDreamExecutable() {
  // 尝试从项目根目录的 _build 查找
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (workspaceFolders && workspaceFolders.length > 0) {
    const rootPath = workspaceFolders[0].uri.fsPath;
    const localDream = path.join(rootPath, '_build', 'default', 'bin', 'main.exe');
    const fs = require('fs');
    if (fs.existsSync(localDream)) {
      return localDream;
    }
  }

  // 尝试从 PATH 查找
  try {
    execSync('which dream', { encoding: 'utf-8' });
    return 'dream';
  } catch (error) {
    return null;
  }
}

// 递归扁平化定义树
function flattenDefinitions(defs) {
  const result = [];
  for (const def of defs) {
    result.push(def);
    if (def.children && def.children.length > 0) {
      result.push(...flattenDefinitions(def.children));
    }
  }
  return result;
}

// 更新文档符号
function updateDocumentSymbols(document) {
  if (document.languageId !== 'dream') return;

  const filePath = document.uri.fsPath;
  const result = analyzeDreamFile(filePath);

  if (result && result.definitions) {
    // 将树状结构扁平化为 id -> definition 映射
    const allDefs = flattenDefinitions(result.definitions);
    const defMap = new Map();
    for (const def of allDefs) {
      defMap.set(def.id, def);
    }
    documentSymbols.set(document.uri.toString(), defMap);
  }
}

// 获取光标位置的单词
function getWordAtPosition(document, position) {
  const range = document.getWordRangeAtPosition(position);
  if (!range) return null;
  return document.getText(range);
}

// 查找光标位置的定义
function findDefinitionAtPosition(defMap, name, position) {
  for (const [id, def] of defMap) {
    // 检查定义位置
    const defRange = def.range;
    if (def.name === name &&
        position.line === defRange.start.line &&
        position.character >= defRange.start.column &&
        position.character <= defRange.end.column) {
      return def;
    }

    // 检查引用位置
    if (def.references) {
      for (const ref of def.references) {
        if (position.line === ref.range.start.line &&
            position.character >= ref.range.start.column &&
            position.character <= ref.range.end.column) {
          // 在引用位置,返回目标定义
          return defMap.get(ref.targetId);
        }
      }
    }
  }
  return null;
}

// Definition Provider
class DreamDefinitionProvider {
  provideDefinition(document, position, token) {
    const defMap = documentSymbols.get(document.uri.toString());
    if (!defMap) return null;

    const word = getWordAtPosition(document, position);
    if (!word) return null;

    const def = findDefinitionAtPosition(defMap, word, position);
    if (!def) return null;

    return new vscode.Location(
      document.uri,
      new vscode.Position(def.range.start.line, def.range.start.column)
    );
  }
}

// Reference Provider
class DreamReferenceProvider {
  provideReferences(document, position, context, token) {
    const defMap = documentSymbols.get(document.uri.toString());
    if (!defMap) return [];

    const word = getWordAtPosition(document, position);
    if (!word) return [];

    // 查找当前位置的定义
    const def = findDefinitionAtPosition(defMap, word, position);
    if (!def) return [];

    const locations = [];

    // 如果需要包含定义
    if (context.includeDeclaration) {
      locations.push(new vscode.Location(
        document.uri,
        new vscode.Position(def.range.start.line, def.range.start.column)
      ));
    }

    // 添加所有引用
    if (def.references) {
      def.references.forEach(ref => {
        locations.push(new vscode.Location(
          document.uri,
          new vscode.Position(ref.range.start.line, ref.range.start.column)
        ));
      });
    }

    return locations;
  }
}

// Rename Provider
class DreamRenameProvider {
  prepareRename(document, position, token) {
    const defMap = documentSymbols.get(document.uri.toString());
    if (!defMap) return null;

    const word = getWordAtPosition(document, position);
    if (!word) return null;

    // 检查是否是一个有效的符号
    const def = findDefinitionAtPosition(defMap, word, position);
    if (!def) return null;

    // 返回要重命名的范围
    const range = document.getWordRangeAtPosition(position);
    return range;
  }

  provideRenameEdits(document, position, newName, token) {
    const defMap = documentSymbols.get(document.uri.toString());
    if (!defMap) return null;

    const word = getWordAtPosition(document, position);
    if (!word) return null;

    // 查找当前位置的定义
    const def = findDefinitionAtPosition(defMap, word, position);
    if (!def) return null;

    // 创建工作区编辑
    const edit = new vscode.WorkspaceEdit();

    // 重命名定义
    const defRange = new vscode.Range(
      new vscode.Position(def.range.start.line, def.range.start.column),
      new vscode.Position(def.range.end.line, def.range.end.column)
    );
    edit.replace(document.uri, defRange, newName);

    // 重命名所有引用
    if (def.references) {
      def.references.forEach(ref => {
        const refRange = new vscode.Range(
          new vscode.Position(ref.range.start.line, ref.range.start.column),
          new vscode.Position(ref.range.end.line, ref.range.end.column)
        );
        edit.replace(document.uri, refRange, newName);
      });
    }

    return edit;
  }
}

// 激活扩展
function activate(context) {
  console.log('Dream Language Extension activated');

  const selector = { scheme: 'file', language: 'dream' };

  // 注册定义提供者
  context.subscriptions.push(
    vscode.languages.registerDefinitionProvider(
      selector,
      new DreamDefinitionProvider()
    )
  );

  // 注册引用提供者
  context.subscriptions.push(
    vscode.languages.registerReferenceProvider(
      selector,
      new DreamReferenceProvider()
    )
  );

  // 注册重命名提供者
  context.subscriptions.push(
    vscode.languages.registerRenameProvider(
      selector,
      new DreamRenameProvider()
    )
  );

  // 监听文档保存（不在每次编辑时都运行 lsp，太慢）
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument(document => {
      if (document.languageId === 'dream') {
        updateDocumentSymbols(document);
      }
    })
  );

  // 监听文档打开
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(document => {
      if (document.languageId === 'dream') {
        updateDocumentSymbols(document);
      }
    })
  );

  // 为当前打开的文档构建符号表
  vscode.workspace.textDocuments.forEach(document => {
    if (document.languageId === 'dream') {
      updateDocumentSymbols(document);
    }
  });
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
