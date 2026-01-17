#!/usr/bin/env node

/**
 * Generates test Contact data with duplicate records for testing duplicate detection.
 * Creates ~5000 records with groups of 2, 3, 4, or 5 duplicates (same email).
 */

const fs = require('fs');
const path = require('path');

const firstNames = [
    'James',
    'John',
    'Robert',
    'Michael',
    'William',
    'David',
    'Richard',
    'Joseph',
    'Thomas',
    'Charles',
    'Christopher',
    'Daniel',
    'Matthew',
    'Anthony',
    'Mark',
    'Donald',
    'Steven',
    'Paul',
    'Andrew',
    'Joshua',
    'Mary',
    'Patricia',
    'Jennifer',
    'Linda',
    'Barbara',
    'Elizabeth',
    'Susan',
    'Jessica',
    'Sarah',
    'Karen',
    'Lisa',
    'Nancy',
    'Betty',
    'Margaret',
    'Sandra',
    'Ashley',
    'Kimberly',
    'Emily',
    'Donna',
    'Michelle',
    'Alex',
    'Jordan',
    'Taylor',
    'Morgan',
    'Casey',
    'Riley',
    'Quinn',
    'Avery',
    'Cameron',
    'Dakota'
];

const lastNames = [
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones',
    'Garcia',
    'Miller',
    'Davis',
    'Rodriguez',
    'Martinez',
    'Hernandez',
    'Lopez',
    'Gonzalez',
    'Wilson',
    'Anderson',
    'Thomas',
    'Taylor',
    'Moore',
    'Jackson',
    'Martin',
    'Lee',
    'Perez',
    'Thompson',
    'White',
    'Harris',
    'Sanchez',
    'Clark',
    'Ramirez',
    'Lewis',
    'Robinson',
    'Walker',
    'Young',
    'Allen',
    'King',
    'Wright',
    'Scott',
    'Torres',
    'Nguyen',
    'Hill',
    'Flores',
    'Green',
    'Adams',
    'Nelson',
    'Baker',
    'Hall',
    'Rivera',
    'Campbell',
    'Mitchell',
    'Carter',
    'Roberts'
];

const nicknames = {
    James: ['Jim', 'Jimmy', 'Jamie'],
    John: ['Johnny', 'Jon', 'Jack'],
    Robert: ['Rob', 'Bob', 'Bobby', 'Robbie'],
    Michael: ['Mike', 'Mikey', 'Mick'],
    William: ['Will', 'Bill', 'Billy', 'Willy'],
    David: ['Dave', 'Davey'],
    Richard: ['Rick', 'Rich', 'Dick', 'Ricky'],
    Joseph: ['Joe', 'Joey'],
    Thomas: ['Tom', 'Tommy'],
    Charles: ['Charlie', 'Chuck', 'Chas'],
    Christopher: ['Chris', 'Topher'],
    Daniel: ['Dan', 'Danny'],
    Matthew: ['Matt', 'Matty'],
    Anthony: ['Tony', 'Ant'],
    Steven: ['Steve', 'Stevie'],
    Jennifer: ['Jen', 'Jenny'],
    Elizabeth: ['Liz', 'Beth', 'Lizzy', 'Betty'],
    Patricia: ['Pat', 'Patty', 'Tricia'],
    Margaret: ['Maggie', 'Meg', 'Peggy'],
    Katherine: ['Kate', 'Katie', 'Kathy'],
    Rebecca: ['Becca', 'Becky'],
    Jessica: ['Jess', 'Jessie'],
    Alexandra: ['Alex', 'Lexi'],
    Kimberly: ['Kim', 'Kimmy'],
    Nicholas: ['Nick', 'Nicky'],
    Benjamin: ['Ben', 'Benny'],
    Timothy: ['Tim', 'Timmy'],
    Gregory: ['Greg', 'Gregg'],
    Samuel: ['Sam', 'Sammy']
};

const titles = [
    'Analyst',
    'Sr Analyst',
    'Lead Analyst',
    'Principal Analyst',
    'Engineer',
    'Sr Engineer',
    'Lead Engineer',
    'Principal Engineer',
    'Staff Engineer',
    'Developer',
    'Sr Developer',
    'Lead Developer',
    'Principal Developer',
    'Manager',
    'Sr Manager',
    'Director',
    'Sr Director',
    'VP',
    'Consultant',
    'Sr Consultant',
    'Principal Consultant',
    'Coordinator',
    'Sr Coordinator',
    'Specialist',
    'Sr Specialist',
    'Associate',
    'Sr Associate',
    'Administrator',
    'Sr Administrator'
];

const departments = [
    'Sales',
    'Marketing',
    'Engineering',
    'Finance',
    'HR',
    'Operations',
    'IT',
    'Legal',
    'Customer Success',
    'Product',
    'Design',
    'Support',
    'Research',
    'Quality Assurance',
    'Business Development',
    'Consulting'
];

const emailDomains = ['example.com', 'test.org', 'sample.net', 'demo.io', 'corp.test'];

function random(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function generatePhone() {
    const area = Math.floor(Math.random() * 900) + 100;
    const exchange = Math.floor(Math.random() * 900) + 100;
    const subscriber = Math.floor(Math.random() * 9000) + 1000;
    return `${area}-${exchange}-${subscriber}`;
}

function generateEmail(firstName, lastName, domain, variant = 0) {
    const formats = [
        `${firstName.toLowerCase()}.${lastName.toLowerCase()}`,
        `${firstName.toLowerCase()}${lastName.toLowerCase()}`,
        `${firstName.toLowerCase()[0]}${lastName.toLowerCase()}`,
        `${firstName.toLowerCase()}_${lastName.toLowerCase()}`,
        `${firstName.toLowerCase()}.${lastName.toLowerCase()[0]}`
    ];
    return `${formats[variant % formats.length]}@${domain}`;
}

function getNameVariant(firstName, index) {
    if (index === 0) return firstName;

    const variants = nicknames[firstName];
    if (variants && variants.length > 0) {
        return variants[(index - 1) % variants.length];
    }

    // Add typo variations
    const typos = [
        firstName,
        firstName.charAt(0).toUpperCase() + firstName.slice(1).toLowerCase(),
        firstName.toUpperCase()
    ];
    return typos[index % typos.length];
}

function generateDuplicateGroup(groupId, duplicateCount) {
    const firstName = random(firstNames);
    const lastName = random(lastNames);
    const domain = random(emailDomains);
    const email = generateEmail(firstName, lastName, domain);
    const baseDepartment = random(departments);

    const records = [];

    for (let i = 0; i < duplicateCount; i++) {
        const nameVariant = getNameVariant(firstName, i);
        const title = random(titles);
        // Sometimes vary department slightly
        const dept = i === 0 || Math.random() > 0.3 ? baseDepartment : random(departments);

        records.push({
            FirstName: nameVariant,
            LastName: lastName,
            Email: email,
            Phone: generatePhone(),
            Title: title,
            Department: dept
        });
    }

    return records;
}

function generateTestData(targetRecords = 5000) {
    const records = [];
    let groupId = 0;

    // Distribution: roughly equal mix of 2, 3, 4, 5 duplicates per group
    // Average group size = 3.5, so we need ~1428 groups for 5000 records
    const duplicateCounts = [2, 3, 4, 5];

    while (records.length < targetRecords) {
        const duplicateCount = duplicateCounts[groupId % duplicateCounts.length];
        const group = generateDuplicateGroup(groupId, duplicateCount);
        records.push(...group);
        groupId++;
    }

    // Shuffle records so duplicates aren't sequential
    for (let i = records.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [records[i], records[j]] = [records[j], records[i]];
    }

    return { records: records.slice(0, targetRecords), groupCount: groupId };
}

function writeCSV(records, outputPath) {
    const headers = ['FirstName', 'LastName', 'Email', 'Phone', 'Title', 'Department'];
    const lines = [headers.join(',')];

    for (const record of records) {
        const values = headers.map((h) => {
            const val = record[h] || '';
            // Escape commas and quotes in CSV
            if (val.includes(',') || val.includes('"')) {
                return `"${val.replace(/"/g, '""')}"`;
            }
            return val;
        });
        lines.push(values.join(','));
    }

    fs.writeFileSync(outputPath, lines.join('\n'));
}

// Main execution
const targetRecords = parseInt(process.argv[2]) || 5000;
const outputPath = path.join(__dirname, '..', 'data', 'Contact.csv');

console.log(`Generating ${targetRecords} test contact records...`);

const { records, groupCount } = generateTestData(targetRecords);

writeCSV(records, outputPath);

console.log(`✓ Generated ${records.length} records in ${groupCount} duplicate groups`);
console.log(`✓ Output: ${outputPath}`);
console.log(`\nDuplicate distribution:`);

// Count actual distribution
const emailCounts = {};
records.forEach((r) => {
    emailCounts[r.Email] = (emailCounts[r.Email] || 0) + 1;
});

const distribution = { 2: 0, 3: 0, 4: 0, 5: 0 };
Object.values(emailCounts).forEach((count) => {
    if (distribution[count] !== undefined) {
        distribution[count]++;
    }
});

console.log(`  Groups of 2: ${distribution[2]}`);
console.log(`  Groups of 3: ${distribution[3]}`);
console.log(`  Groups of 4: ${distribution[4]}`);
console.log(`  Groups of 5: ${distribution[5]}`);
