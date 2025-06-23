// storage.js
const API_URL = 'https://jsonplaceholder.typicode.com';

class PublicStorage {
    constructor() {
        this.token = null;
    }

    async authenticate(username, password) {
        // Envoyer les credentials à l'API
        const response = await fetch(`${API_URL}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        if (!response.ok) throw new Error('Échec de l\'authentification');
        
        const { token } = await response.json();
        this.token = token;
        return token;
    }

    async saveData(data) {
        if (!this.token) throw new Error('Non authentifié');
        
        const response = await fetch(`${API_URL}/data`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.token}`
            },
            body: JSON.stringify(data)
        });

        if (!response.ok) throw new Error('Échec de la sauvegarde');
        return response.json();
    }

    async loadData() {
        if (!this.token) throw new Error('Non authentifié');
        
        const response = await fetch(`${API_URL}/data`, {
            headers: { 'Authorization': `Bearer ${this.token}` }
        });

        if (!response.ok) throw new Error('Échec du chargement');
        return response.json();
    }

    async syncData(localData) {
        try {
            const serverData = await this.loadData();
            // Logique de synchronisation basique
            const mergedData = {
                ...serverData,
                interventions: [
                    ...serverData.interventions,
                    ...localData.interventions.filter(
                        local => !serverData.interventions.some(s => s.id === local.id)
                    )
                ],
                nextId: Math.max(serverData.nextId, localData.nextId)
            };
            return await this.saveData(mergedData);
        } catch (error) {
            console.error('Erreur de synchronisation:', error);
            throw error;
        }
    }
}

// Exemple d'utilisation
const storage = new PublicStorage();

// Authentification
storage.authenticate('admin', '5513090807**Aa')
    .then(() => {
        const data = {
            interventions: [],
            nextId: 1
        };
        
        // Sauvegarde initiale
        return storage.saveData(data);
    })
    .then(() => console.log('Données initialisées avec succès'))
    .catch(err => console.error('Erreur:', err));

export default storage;