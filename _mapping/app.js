// Tab switching
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        const targetTab = tab.dataset.tab;

        // Update active tab button
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        // Update active panel
        document.querySelectorAll('.tab-panel').forEach(panel => panel.classList.remove('active'));
        document.getElementById(targetTab).classList.add('active');
    });
});

// Render files grid
function renderFiles(files = architectureData.files) {
    const grid = document.getElementById('fileGrid');
    grid.innerHTML = files.map(file => `
        <div class="file-card">
            <h3>${file.name}</h3>
            <span class="category">${file.category}</span>
            <p class="purpose">${file.purpose}</p>
            <div class="types">Types: ${file.types.slice(0, 3).join(', ')}${file.types.length > 3 ? '...' : ''}</div>
            <div style="margin-top: 0.5rem; color: #808080; font-size: 0.75rem;">
                ${file.dependencies.length} dependencies
            </div>
        </div>
    `).join('');
}

// File search
document.getElementById('fileSearch').addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase();
    const filtered = architectureData.files.filter(file =>
        file.name.toLowerCase().includes(query) ||
        file.purpose.toLowerCase().includes(query) ||
        file.category.toLowerCase().includes(query) ||
        file.types.some(t => t.toLowerCase().includes(query))
    );
    renderFiles(filtered);
});

// Render architecture view
function renderArchitecture() {
    const container = document.getElementById('architectureContent');
    const arch = architectureData.architecture;

    const sections = [
        { title: 'App Entry Point', key: 'app', color: '#ce9178' },
        { title: 'Views', key: 'views', color: '#4ec9b0' },
        { title: 'Managers', key: 'managers', color: '#dcdcaa' },
        { title: 'Models', key: 'models', color: '#4fc1ff' },
        { title: 'Utilities', key: 'utilities', color: '#c586c0' }
    ];

    container.innerHTML = sections.map(section => `
        <div class="architecture-section">
            <h3 style="color: ${section.color}">${section.title} (${arch[section.key].length})</h3>
            <div class="file-list">
                ${arch[section.key].map(file => `
                    <div class="file-badge" style="border-left: 3px solid ${section.color}">${file}</div>
                `).join('')}
            </div>
        </div>
    `).join('');
}

// Render data flow
function renderDataFlow() {
    const container = document.getElementById('dataflowContent');
    const flows = architectureData.dataFlow;

    container.innerHTML = Object.entries(flows).map(([key, flow]) => `
        <div class="flow-diagram">
            <h4>${key.replace(/([A-Z])/g, ' $1').trim().replace(/^./, str => str.toUpperCase())}</h4>
            <div class="flow-path">${flow.flow}</div>
            <div class="flow-desc">${flow.description}</div>
        </div>
    `).join('');
}

// Render features
function renderFeatures() {
    const list = document.getElementById('featureList');
    list.innerHTML = architectureData.keyFeatures.map(feature => `
        <li>${feature}</li>
    `).join('');
}

// Render relationship graph
function renderGraph() {
    const canvas = document.getElementById('relationshipCanvas');
    const ctx = canvas.getContext('2d');

    // Set canvas size
    const container = canvas.parentElement;
    canvas.width = container.clientWidth;
    canvas.height = 800;

    // Build node positions
    const files = architectureData.files;
    const categories = {
        'App': { x: canvas.width / 2, y: 50, color: '#ce9178', nodes: [] },
        'View': { x: 150, y: 200, color: '#4ec9b0', nodes: [] },
        'Manager': { x: canvas.width / 2, y: 200, color: '#dcdcaa', nodes: [] },
        'Model': { x: canvas.width - 150, y: 200, color: '#4fc1ff', nodes: [] },
        'Utility': { x: canvas.width - 150, y: 500, color: '#c586c0', nodes: [] }
    };

    // Group files by category
    files.forEach(file => {
        const cat = categories[file.category];
        if (cat) {
            cat.nodes.push(file);
        }
    });

    // Calculate positions for each node in its category
    const nodePositions = {};
    Object.entries(categories).forEach(([catName, cat]) => {
        const count = cat.nodes.length;
        const spacing = catName === 'View' ? 60 : 80;
        const startY = cat.y;

        cat.nodes.forEach((node, i) => {
            nodePositions[node.name] = {
                x: cat.x + (i % 2 === 0 ? -100 : 100),
                y: startY + (Math.floor(i / 2) * spacing),
                color: cat.color
            };
        });
    });

    // Draw relationships
    ctx.strokeStyle = '#3e3e42';
    ctx.lineWidth = 1;
    architectureData.relationships.forEach(rel => {
        const from = nodePositions[rel.from];
        const to = nodePositions[rel.to];

        if (from && to) {
            ctx.beginPath();
            ctx.moveTo(from.x, from.y);
            ctx.lineTo(to.x, to.y);
            ctx.stroke();
        }
    });

    // Draw nodes
    Object.entries(nodePositions).forEach(([name, pos]) => {
        // Draw circle
        ctx.fillStyle = pos.color;
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, 8, 0, Math.PI * 2);
        ctx.fill();

        // Draw label
        ctx.fillStyle = '#d4d4d4';
        ctx.font = '11px -apple-system, sans-serif';
        ctx.textAlign = 'center';
        const shortName = name.replace('.swift', '');
        ctx.fillText(shortName, pos.x, pos.y + 25);
    });

    // Draw legend
    let legendY = 20;
    Object.entries(categories).forEach(([name, cat]) => {
        ctx.fillStyle = cat.color;
        ctx.beginPath();
        ctx.arc(20, legendY, 6, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = '#d4d4d4';
        ctx.font = '12px -apple-system, sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText(name, 35, legendY + 4);

        legendY += 25;
    });
}

// Initialize
renderFiles();
renderArchitecture();
renderDataFlow();
renderFeatures();
renderGraph();

// Re-render graph on tab switch
document.querySelector('[data-tab="graph"]').addEventListener('click', () => {
    setTimeout(renderGraph, 100);
});

// Handle window resize
window.addEventListener('resize', () => {
    if (document.getElementById('graph').classList.contains('active')) {
        renderGraph();
    }
});
