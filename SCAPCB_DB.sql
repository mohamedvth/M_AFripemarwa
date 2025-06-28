-- Création de la base de données
CREATE DATABASE SCAPCB_DB;
GO

USE SCAPCB_DB;
GO

-- Table des utilisateurs
CREATE TABLE Utilisateurs (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    NomUtilisateur NVARCHAR(50) NOT NULL UNIQUE,
    MotDePasse NVARCHAR(255) NOT NULL,
    NomComplet NVARCHAR(100) NOT NULL,
    Matricule NVARCHAR(20) NOT NULL,
    Role NVARCHAR(20) NOT NULL DEFAULT 'Technicien',
    DateCreation DATETIME NOT NULL DEFAULT GETDATE(),
    DerniereConnexion DATETIME NULL
);
GO

-- Table des équipements
CREATE TABLE Equipements (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nom NVARCHAR(100) NOT NULL,
    Description NVARCHAR(255) NULL,
    Localisation NVARCHAR(100) NULL,
    Statut NVARCHAR(20) NOT NULL DEFAULT 'Fonctionnel',
    DateAjout DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- Table des types d'intervention
CREATE TABLE TypesIntervention (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20) NOT NULL UNIQUE,
    Libelle NVARCHAR(50) NOT NULL,
    Description NVARCHAR(255) NULL
);
GO

-- Table des statuts d'intervention
CREATE TABLE StatutsIntervention (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20) NOT NULL UNIQUE,
    Libelle NVARCHAR(50) NOT NULL
);
GO

-- Table principale des interventions
CREATE TABLE Interventions (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    UtilisateurID INT NOT NULL,
    TypeInterventionID INT NOT NULL,
    StatutID INT NOT NULL,
    Priorite NVARCHAR(20) NOT NULL CHECK (Priorite IN ('Haute', 'Moyenne', 'Basse')),
    Description TEXT NULL,
    DateDebut DATETIME NOT NULL,
    DateFin DATETIME NOT NULL,
    DateCreation DATETIME NOT NULL DEFAULT GETDATE(),
    DateModification DATETIME NULL,
    CONSTRAINT FK_Intervention_Utilisateur FOREIGN KEY (UtilisateurID) REFERENCES Utilisateurs(ID),
    CONSTRAINT FK_Intervention_Type FOREIGN KEY (TypeInterventionID) REFERENCES TypesIntervention(ID),
    CONSTRAINT FK_Intervention_Statut FOREIGN KEY (StatutID) REFERENCES StatutsIntervention(ID)
);
GO

-- Table de liaison Intervention-Équipement
CREATE TABLE InterventionEquipements (
    InterventionID INT NOT NULL,
    EquipementID INT NOT NULL,
    PRIMARY KEY (InterventionID, EquipementID),
    CONSTRAINT FK_IE_Intervention FOREIGN KEY (InterventionID) REFERENCES Interventions(ID),
    CONSTRAINT FK_IE_Equipement FOREIGN KEY (EquipementID) REFERENCES Equipements(ID)
);
GO

-- Table des logs d'activité
CREATE TABLE LogsActivite (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    UtilisateurID INT NOT NULL,
    Action NVARCHAR(50) NOT NULL,
    Details TEXT NULL,
    DateAction DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Logs_Utilisateur FOREIGN KEY (UtilisateurID) REFERENCES Utilisateurs(ID)
);
GO

-- Insertion des données de base
INSERT INTO TypesIntervention (Code, Libelle, Description)
VALUES 
    ('ELEC', 'Maintenance Électrique', 'Interventions sur les systèmes électriques'),
    ('MECA', 'Maintenance Mécanique', 'Interventions sur les systèmes mécaniques'),
    ('SGEN', 'Service Général', 'Interventions diverses et générales');
    
INSERT INTO StatutsIntervention (Code, Libelle)
VALUES 
    ('PLAN', 'Planifiée'),
    ('ECOU', 'En Cours'),
    ('TERM', 'Terminée'),
    ('ANUL', 'Annulée');
    
-- Création d'un utilisateur admin
INSERT INTO Utilisateurs (NomUtilisateur, MotDePasse, NomComplet, Matricule, Role)
VALUES (
    'admin', 
    HASHBYTES('SHA2_256', '5513090807**Aa'), 
    'Administrateur Système', 
    'ADM001', 
    'Admin'
);
GO

-- Création des vues utiles
CREATE VIEW VueInterventionsDetails AS
SELECT 
    i.ID,
    u.NomComplet AS Technicien,
    u.Matricule,
    ti.Libelle AS TypeIntervention,
    si.Libelle AS Statut,
    i.Priorite,
    i.Description,
    i.DateDebut,
    i.DateFin,
    i.DateCreation,
    STUFF((
        SELECT ', ' + e.Nom
        FROM InterventionEquipements ie
        JOIN Equipements e ON ie.EquipementID = e.ID
        WHERE ie.InterventionID = i.ID
        FOR XML PATH('')
    ), 1, 2, '') AS Equipements
FROM Interventions i
JOIN Utilisateurs u ON i.UtilisateurID = u.ID
JOIN TypesIntervention ti ON i.TypeInterventionID = ti.ID
JOIN StatutsIntervention si ON i.StatutID = si.ID;
GO

-- Procédures stockées
CREATE PROCEDURE CreerIntervention
    @UserID INT,
    @TypeInterventionID INT,
    @StatutID INT,
    @Priorite NVARCHAR(20),
    @Description TEXT,
    @DateDebut DATETIME,
    @DateFin DATETIME,
    @Equipements NVARCHAR(MAX)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION
        
        INSERT INTO Interventions (
            UtilisateurID,
            TypeInterventionID,
            StatutID,
            Priorite,
            Description,
            DateDebut,
            DateFin
        )
        VALUES (
            @UserID,
            @TypeInterventionID,
            @StatutID,
            @Priorite,
            @Description,
            @DateDebut,
            @DateFin
        );
        
        DECLARE @NewInterventionID INT = SCOPE_IDENTITY();
        
        INSERT INTO InterventionEquipements (InterventionID, EquipementID)
        SELECT @NewInterventionID, value
        FROM STRING_SPLIT(@Equipements, ',');
        
        COMMIT TRANSACTION
        RETURN @NewInterventionID
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        RETURN -1
    END CATCH
END
GO

-- Création des rôles et permissions
CREATE ROLE MaintenanceAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES TO MaintenanceAdmin;

CREATE ROLE Technicien;
GRANT SELECT, INSERT, UPDATE ON Interventions TO Technicien;
GRANT SELECT ON Equipements TO Technicien;
GRANT SELECT ON TypesIntervention TO Technicien;
GRANT SELECT ON StatutsIntervention TO Technicien;
GO