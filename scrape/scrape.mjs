import scrape from 'website-scraper'; // only as ESM, no CommonJS
const options = {
  urls: ['https://www.ealingwoodcraft.org.uk/'],
  directory: './scraped',
  maxRecursiveDepth : 10,
  recursive: true,
  urlFilter: function(url) {
    return url.indexOf('https://www.ealingwoodcraft.org.uk') === 0 || url.indexOf('http://www.ealingwoodcraft.org.uk') === 0;
  },
  filenameGenerator: 'bySiteStructure',
}

// with async/await
const result = await scrape(options);